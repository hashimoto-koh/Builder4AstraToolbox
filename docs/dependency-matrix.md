# 依存関係マトリクス (dependency-matrix.md)

本書は `libastra`（ASTRA Toolbox + Julia C ABI）のビルド時および実行時における依存ライブラリ、ツールチェーン、プラットフォーム要件をまとめた文書である。

---

## 1. 共有ライブラリの動的リンク依存 (ELF NEEDED)

実機上の現行ビルド生成物（`/home/jov/git/prj/AstraToolbox.jl/deps/usr/lib/libastra.so`）の動的セクション（`readelf -d`）の検査結果:

| NEEDED 共有ライブラリ | 用途 | 由来 / JLL 解決方針 |
| :--- | :--- | :--- |
| `libcudart.so.12` | CUDA Runtime API | `CUDA_Runtime_jll` (CUDA 12) |
| `libcufft.so.11` | CUDA FFT ライブラリ | `CUDA_Runtime_jll` / `CUDA_SDK_jll` (CUFFT) |
| `libstdc++.so.6` | C++ 標準ライブラリ | BinaryBuilder GCC ツールチェーン (`CompilerSupportLibraries_jll`) |
| `libm.so.6` | 算術ライブラリ | glibc |
| `libc.so.6` | C 標準ライブラリ | glibc |
| `ld-linux-x86-64.so.2` | 動的リンカ | glibc |
| `libgcc_s.so.1` | GCC ランタイム | BinaryBuilder GCC ツールチェーン |

- **SONAME**: `libastra.so.0`
- **RPATH / RUNPATH**: `/usr/local/lib/../lib64` (JLL 化時は `$ORIGIN` または BinaryBuilder 標準の RPATH 設定に置換)

### 1.1 外部ライブラリに関する重要な発見
- **FFTW**: upstream configure では FFTW をチェックしているが、現行のビルドログおよび `readelf` 結果より、外部 `libfftw3` にはリンクされていない（CUDA 側の `libcufft` および ASTRA 内部実装が利用されている）。
- **XML**: ASTRA は TinyXML 由来のコード（`XMLConfig.cpp`, `XMLDocument.cpp`, `XMLNode.cpp`）を内部ソースツリーに保持しており、外部 `libxml2` 等の依存は一切不要。
- **Boost**: `libboost_unit_test_framework` はテストスイートでのみ使用され、`libastra.so` 本体のリンクには不要（`configure` 時になくても本体ビルドは通過）。
- **Python / MATLAB**: `--with-python=no --with-matlab=no` でビルドするため、Python, NumPy, MATLAB SDK への依存は一切発生しない。

---

## 2. ツールチェーン要件

### 2.1 ビルドツール
- **Autotools**: `autoconf` (>= 2.69), `automake`, `libtool`
  - upstream リポジトリからビルドする際は `build/linux/autogen.sh` を実行して `configure` スクリプトおよび Makefile テンプレートを生成する。
- **Host C++ Compiler**: `g++` (C++17 対応, GCC 11/12 以上)
- **CUDA Compiler**: `nvcc` (CUDA 12 系)
  - `CUDA_SDK_jll` または BinaryBuilder の CUDA platform helper を通じて提供。

---

## 3. プラットフォームおよび GPU アーキテクチャ要件

### 3.1 対象プラットフォーム
- **OS / アーキテクチャ**: `Linux x86_64` (glibc >= 2.17)
- **GPU 動作保証環境**:
  - NVIDIA GPU（実機検証対象: GeForce RTX 3090, `sm_86`）
  - NVIDIA Driver: >= 525.60.13 (CUDA 12.0 対応ドライバ以上。検証機は Driver 570.211.01)
  - **配布対象**: CUDA-enabled JLL のみ。CPU-only JLL や CPU-only artifact は作成・配布しない。

### 3.2 CUDA アーキテクチャ (Compute Capabilities)
ASTRA Toolbox の `configure.ac` は `--with-cuda-compute=archs` オプションを提供しており、デフォルトは `all-major` である。
CUDA 12 系においてサポートされる主要 Compute Model:
- `sm_50`, `sm_60`, `sm_70`, `sm_75`, `sm_80`, `sm_86`, `sm_89`, `sm_90`
- および最新 PTX（将来互換性のため）
- BinaryBuilder recipe においては、実機である `sm_86` を確実に含めつつ、BinaryBuilder の artifact サイズ制限を考慮して適切な architecture list を構成する。

---

## 4. BinaryBuilder / Yggdrasil 設計方針

1. **単一 JLL Product**:
   - Product 名: `libastra` (`LibraryProduct("libastra", :libastra)`)
   - JLL 名: `AstraToolbox_jll`
2. **Dependencies**:
   - `CUDA_Runtime_jll` (CUDA 12 系)
   - `CompilerSupportLibraries_jll`
3. **Build Script の基本骨子**:
   - upstream ソースコード取得（固定 commit: `bd0323e9b4b243ee90bca41341927b05e6e816c8`）
   - パッチ適用（`darthelper.cu` タイポ修正、`Makefile.in` への `julia_c_api.lo` 追加）
   - wrapper ソース（`julia_c_api.h`, `julia_c_api.cpp`）の配置
   - `./autogen.sh`
   - `./configure --prefix=${prefix} --host=${target} --with-cuda=${prefix}/cuda ... --with-python=no`
   - `make -j${nproc} libastra.la`
   - `make install` または `.libs/libastra.so*` を `${libdir}` にインストール
