# AstraToolbox 実装調査記録 (inventory.md)

本書は `AstraToolbox.jl` のネイティブビルドを BinaryBuilder による JLL 配布（仮称: `AstraToolbox_jll`）へ移行するための、現行実装・upstream・依存関係の棚卸し結果である。

---

## 1. 調査対象リビジョン

### 1.1 AstraToolbox.jl
- **リポジトリパス**: `/home/jov/git/prj/AstraToolbox.jl` (本 workspace では参照のみ。変更不可)
- **Git Commit**: `caf2d0e3065cde52368bf5c63308f3363a902724`
- **ブランチ**: `master` (origin/master と同期済み)
- **ライセンス**: GPL-3.0-or-later

### 1.2 Upstream ASTRA Toolbox
- **リポジトリ**: `https://github.com/astra-toolbox/astra-toolbox.git`
- **固定 Commit**: `bd0323e9b4b243ee90bca41341927b05e6e816c8` (AstraToolbox.jl `deps/build.jl` の `DEFAULT_ASTRA_REF` と一致)
- **ライセンス**: GPL-3.0-or-later
- **著作者**: imec-Vision Lab (University of Antwerp) & CWI (Amsterdam)

---

## 2. 現行 deps/build.jl の処理フロー解析

`AstraToolbox.jl/deps/build.jl` は、ユーザー環境でのローカルビルドを行うスクリプトであり、以下のステップを順次実行している:

1. **CUDA ルート検出 (`detect_cuda_root`)**:
   - 環境変数 `ASTRATOOLBOXJL_CUDA`, `CUDA_ROOT`, `CUDA_HOME` を検査。
   - なければ `/usr/local/cuda` を確認。
   - なければ `which nvcc` から親ディレクトリを特定。
   - **いずれも見つからない場合はエラー終了**（CPU-only への自動フォールバックは実装されていない）。
2. **Upstream ソース取得 (`acquire_astra_source`)**:
   - `SOURCE_ROOT = deps/work/astra-toolbox` に git clone。
   - 固定 ref `bd0323e9b4b243ee90bca41341927b05e6e816c8` を checkout。
3. **Upstream ソースパッチ (`patch_upstream_sources`)**:
   - `cuda/2d/darthelper.cu` 内のタイポ修正:
     - 変更前: `d[o2 - 1] != d[o2] ||                  d[o3 + 1] != d[o2] ||`
     - 変更後: `d[o2 - 1] != d[o2] ||                  d[o2 + 1] != d[o2] ||`
4. **Julia C ABI Wrapper 注入 (`install_wrapper_files`)**:
   - `deps/wrapper/include/astra/julia_c_api.h` を `include/astra/julia_c_api.h` にコピー。
   - `deps/wrapper/src/julia_c_api.cpp` を `src/julia_c_api.cpp` にコピー。
5. **Makefile.in のパッチ (`patch_makefile`)**:
   - `build/linux/Makefile.in` の `src/Globals.lo \` の直後に `\tsrc/julia_c_api.lo \` を追加。
6. **Autotools ビルド (`build_astra`)**:
   - `cd build/linux`
   - `./autogen.sh`
   - `./configure --with-cuda=$cuda_root --with-python=no`
   - `make -j8 libastra.la`
7. **生成物の配置と deps.jl 出力 (`install_library`)**:
   - `build/linux/.libs/libastra.so` (実体は `libastra.so.0.0.0`) を `deps/usr/lib/libastra.so` にコピー。
   - `deps/deps.jl` に `const libastra = "/home/jov/git/prj/AstraToolbox.jl/deps/usr/lib/libastra.so"` を書き出し。

---

## 3. Julia 側 (AstraToolbox.jl) のライブラリ解決・呼出方式

### 3.1 ライブラリ解決メカニズム (`src/LowLevel.jl`, `src/lowlevel_common.jl`)
- `deps/deps.jl` が存在する場合は `include(_deps_path)` して `const libastra` を定義。
- `library_path()` の優先順位:
  1. 環境変数 `ASTRA_JULIA_LIB`
  2. `deps.jl` の `libastra`、または fallback として `deps/usr/lib/libastra.so`
  3. システムパスの `"libastra.so"`
- `set_library!(path)` を呼ぶことで実行時にロード対象共有ライブラリのパスを上書き可能。
- `_libhandle()` で `Libdl.dlopen(library_path())` を取得し、各 binding 関数が `Libdl.dlsym(lib, :astra_julia_...)` でシンボルを動的解決して `ccall` を実行。

### 3.2 エラー処理規約
- C API 呼び出しの戻り値:
  - 成功: `1`
  - 失敗: `0`
- 失敗時は C++ 側の thread-local ストレージにエラー文字列が記録され、Julia 側から `astra_julia_last_error()` (Julia 関数: `LowLevel.last_error()`) でエラーメッセージを取得して Julia の例外（`ErrorException` など）を送出する規約になっている。

---

## 4. Yggdrasil / General Registry 調査

- **Yggdrasil (`JuliaPackaging/Yggdrasil`)**:
  - `A/` ディレクトリ配下に `AstraToolbox` や `Astra` に該当する recipe は存在しない。
  - コード検索結果でも、ASTRA Toolbox 本体の recipe は登録されていないことを確認。
- **General Registry (`JuliaRegistries/General`)**:
  - `AstraToolbox_jll`、`ASTRA_jll`、`libastra_jll` というパッケージは未登録。
- **結論**:
  - JLL パッケージ名として `AstraToolbox_jll` は命名競合がなく、そのまま採用可能。
  - ASTRA 本体の JLL と wrapper JLL を分離する必要はなく、**ASTRA C++ + CUDA + Julia C ABI を一体に含む単一 JLL** としてビルドするのが最も簡潔で保守性が高い。

---

## 5. ライセンスと再配布条件の確認

- **ASTRA Toolbox upstream**: GNU General Public License v3.0 or later (GPL-3.0-or-later)。
- **AstraToolbox.jl / Wrapper**: GPL-3.0-or-later。
- **CUDA Runtime / CUFFT**: NVIDIA CUDA Toolkit SLA に基づく再配布。Yggdrasil 上で公式に提供されている `CUDA_Runtime_jll` などの再配布可能バイナリを利用可能。
- **免責・クレジット表示**:
  - 公式 ASTRA Toolbox (imec-Vision Lab / CWI) の著作権表示および論文引用（Optics Express 2016, Ultramicroscopy 2015）を `THIRD_PARTY_NOTICES.md` に明記する。
  - 公式チームの支援・公認を示唆しない非公式ビルドであることを明記する。
