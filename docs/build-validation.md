# ビルド・検証仕様書 (build-validation.md)

本書は `Builder4AstraToolbox` における CUDA-enabled 単一 JLL の仕様、プラットフォーム要件、CUDA アーキテクチャ設計、および受入検証基準を定める。

---

## 1. CUDA-enabled 単一 JLL の確定方針

### 1.1 単一 JLL (`AstraToolbox_jll`) のみを作成・配布
- **配布対象**: **Linux x86_64 向け CUDA-enabled JLL のみ**とする。
- **CPU-only JLL の完全排除**: CPU-only JLL、CPU-only artifact、CPU-only 用 build variant は一切作成・配布しない。
- **サポート境界**: GPU を搭載しない環境での動作保証やインストールサポートは対象外とする。GPU なし環境での dlopen 成功や CPU 演算成功を受入条件に含めない。

### 1.2 CPU アルゴリズムの維持と実機検証根拠
- CUDA-enabled にビルドされた `libastra.so` は、CUDA カーネルだけでなく CPU 用の 2D プロジェクション・再構成アルゴリズム（Parallel/FanFlat FP/BP, FBP, SIRT, SART, CGLS, ART, SparseMatrix 等）をすべて内包している。
- **実機検証結果**:
  GeForce RTX 3090 / CUDA 12.8 環境において、同一の CUDA-enabled `libastra.so` を用いて以下の通り CPU / CUDA 双方の演算が正常に動作し、同一の出力を返すことを確認した:
  - `project(volume, geom; backend = cpu())` -> `Float32[4.0 7.0; 6.0 3.0]`
  - `project(volume, geom; backend = cuda())` -> `Float32[4.0 7.0; 6.0 3.0]` (完全一致)
  - `backproject(sino, geom; volume_size = (2, 2), backend = cpu())` -> `Float32[7.0 11.0; 9.0 13.0]`
  - `backproject(sino, geom; volume_size = (2, 2), backend = cuda())` -> `Float32[7.0 11.0; 9.0 13.0]` (完全一致)
- したがって、単一の CUDA-enabled JLL を配布するだけで、Julia 側の `backend=cpu()` と `backend=cuda()` の双方の機能要件を完全に満たすことができる。

---

## 2. プラットフォームおよび GPU / CUDA 仕様

### 2.1 対象プラットフォーム
- **Target Triplet**: `x86_64-linux-gnu`
- **glibc 要件**: >= 2.17
- **CUDA バージョン**: CUDA 12 系 (CUDA 12.0 〜 12.8)
- **NVIDIA Driver 要件**: >= 525.60.13 (検証機: Driver 570.211.01)
- **実機検証対象 GPU**: NVIDIA GeForce RTX 3090 (`sm_86`)

### 2.2 CUDA Compute Capabilities / Architecture 設計
BinaryBuilder / nvcc でのビルド対象アーキテクチャ:
- `sm_50` (Maxwell)
- `sm_60` (Pascal)
- `sm_70` (Volta)
- `sm_75` (Turing)
- `sm_80` (Ampere A100)
- `sm_86` (Ampere RTX 30xx, 実機検証機)
- `sm_89` (Ada Lovelace RTX 40xx)
- `sm_90` (Hopper)
- `compute_90` PTX (将来アーキテクチャに対する JIT コンパイル用フォールバック)

**バイナリサイズ検討**:
上記アーキテクチャを含めた `libastra.so` のファイルサイズは約 10〜15MB 程度であり、BinaryBuilder artifact の制限（数百 MB〜数 GB）に対して極めて軽量である。

---

## 3. ライブラリ命名とシンボル規約

- **共有ライブラリ名**: `libastra.so` (SONAME: `libastra.so.0`)
  - upstream Autotools の標準出力名をそのまま維持し、ビルドスクリプトの複雑化を防ぐ。
- **JLL Product 定義**:
  ```julia
  products = [
      LibraryProduct("libastra", :libastra)
  ]
  ```
- **名前空間と衝突回避**:
  - JLL artifact は専用ディレクトリ（`~/.julia/artifacts/<hash>/lib/`）に配置され、Julia からは完全修飾パスでロードされるため、システムにインストールされた他の `libastra` と衝突しない。
  - ユーザー環境変数 `ASTRA_JULIA_LIB` および `LowLevel.set_library!(path)` によるカスタムライブラリへのオーバーライド機構は将来もそのまま維持する。

---

## 4. ソースコードおよびパッチの管理規約

1. **Upstream ソースコード**:
   - `https://github.com/astra-toolbox/astra-toolbox.git`
   - 固定 commit: `bd0323e9b4b243ee90bca41341927b05e6e816c8`
   - upstream source tree を本リポジトリに vendor せず、BinaryBuilder の GitSource または archive source として取得する。
2. **Wrapper ソースコード**:
   - `Builder4AstraToolbox/wrapper/include/astra/julia_c_api.h`
   - `Builder4AstraToolbox/wrapper/src/julia_c_api.cpp`
   - 本リポジトリ内に wrapper を配置し、Yggdrasil recipe から直接参照・注入できるようにする。
   - `AstraToolbox.jl/deps/wrapper/` との同一性をスクリプトで検証可能にする。
3. **Upstream 修正パッチ**:
   - `patches/0001-fix-darthelper-typo.patch`: `cuda/2d/darthelper.cu` の `o3+1` タイポ修正
   - `patches/0002-add-julia-c-api-to-makefile.patch`: `build/linux/Makefile.in` への `src/julia_c_api.lo` 追加

---

## 5. 受入検証基準 (Acceptance Criteria)

Phase 3 および Phase 4 において、以下の受入基準を満たすことをもって合格とする:

1. **静的検証 (ABI 整合性)**:
   - `nm -D --defined-only libastra.so | grep " astra_julia_"` の出力が全 114 個のシンボルと完全一致すること。
   - `readelf -d` において不要な外部動的依存（FFTW, XML2 等）が存在せず、`libcudart.so.12` / `libcufft.so.11` / C++ ランタイムのみにリンクされていること。
2. **GPU 認識検証**:
   - NVIDIA RTX 3090 搭載環境において:
     - `astra_julia_has_cuda() == 1`
     - `astra_julia_get_gpu_count() >= 1`
3. **数値同一性検証**:
   - 固定されたテスト入力データを用い、旧ローカルビルド（`AstraToolbox.jl/deps/usr/lib/libastra.so`）と新 JLL ビルドの出力を直接比較。
   - CPU 演算（Parallel / FanFlat FP, BP, FBP, SIRT）: 相対誤差 $< 10^{-6}$
   - CUDA 演算（2D/3D Parallel / FanFlat / Cone FP, BP, FDK, SIRT, CGLS）: 相対誤差 $< 10^{-5}$ (GPU 非決定性および浮動小数点丸め誤差の許容範囲内)
