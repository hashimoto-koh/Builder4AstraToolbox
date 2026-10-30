# upstream 適用パッチ一覧 (patches/README.md)

本ディレクトリのパッチは、upstream ASTRA Toolbox（commit: `bd0323e9b4b243ee90bca41341927b05e6e816c8`）に対して適用するパッチである。

---

## 1. `0001-fix-darthelper-typo.patch`
- **対象ファイル**: `cuda/2d/darthelper.cu`
- **目的**: 4 近傍判定ロジックにおけるインデックス参照のタイポ修正。
- **背景**:
  元コードでは `d[o3 + 1]` を参照しているが、4 近傍の走査（上・左・右・下）における右側のピクセルインデックスは `o2 + 1` であるべきところ、誤って `o3 + 1` と記述されていた。
- **由来**: `AstraToolbox.jl/deps/build.jl` の `patch_upstream_sources()` より抽出。

---

## 2. `0002-add-julia-c-api-to-makefile.patch`
- **対象ファイル**: `build/linux/Makefile.in`
- **目的**: ASTRA 本体の共有ライブラリ `libastra.la` のビルド対象オブジェクト（`BASE_OBJECTS`）に `src/julia_c_api.lo` を追加する。
- **背景**:
  Julia 用 C ABI bridge の実装 `src/julia_c_api.cpp` をコンパイルし、`libastra.so` に同封するために Makefile テンプレートを更新する。
- **由来**: `AstraToolbox.jl/deps/build.jl` の `patch_makefile()` より抽出。
