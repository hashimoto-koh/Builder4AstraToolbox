# AstraToolbox.jl 統合・移行ガイド (integration-guide.md)

本書は `AstraToolbox_jll` を `AstraToolbox.jl` へ統合するためのローダー変更案、PR 差分設計、互換性検証手順をまとめたガイドである。
※ 注意: `/home/jov/git/prj/AstraToolbox.jl` は参照専用とし、本リポジトリ側から直接の変更は行わない。本ガイドの差分は PR 提案用である。

---

## 1. 統合の基本方針

1. **既存 API の完全維持**:
   - `LowLevel.set_library!(path)`
   - `LowLevel.library_path()`
   - `LowLevel.has_cuda()`
   - `LowLevel.get_gpu_info()`
   - `LowLevel.last_error()`
   - public Julia API（`project`, `backproject`, `reconstruct`, `fbp`, `sirt`, etc.）は一切変更しない。
2. **優先順位契約の維持**:
   ライブラリ探索の優先順位は以下のように維持・拡張する:
   1. 環境変数 `ASTRA_JULIA_LIB`（開発者・カスタムビルドの最優先オーバーライド）
   2. `AstraToolbox_jll.libastra_path`（JLL アーティファクト経由。新規追加）
   3. `deps/deps.jl` で定義された `libastra`（従来のローカルビルド生成物）
   4. システムの `"libastra.so"`
3. **段階的移行**:
   - 初期段階では既存の `deps/build.jl` を即座に削除せず併存させる。
   - JLL による読み込みが標準化され、十分な実機検証期間を経た後に `deps/build.jl` を非推奨化・廃止する。

---

## 2. AstraToolbox.jl への変更案 (PR Diff)

### 2.1 `src/lowlevel_common.jl` の変更案
```diff
--- a/src/lowlevel_common.jl
+++ b/src/lowlevel_common.jl
@@ -1,9 +1,15 @@
 function _default_library_candidates()
     package_root = normpath(joinpath(@__DIR__, ".."))
     built_lib = @isdefined(libastra) ? libastra : joinpath(package_root, "deps", "usr", "lib", "libastra.so")
-    String[
-        get(ENV, "ASTRA_JULIA_LIB", ""),
-        built_lib,
-        "libastra.so",
-    ]
+    candidates = String[get(ENV, "ASTRA_JULIA_LIB", "")]
+    
+    # Prefer JLL artifact if available
+    if isdefined(@__MODULE__, :AstraToolbox_jll)
+        push!(candidates, AstraToolbox_jll.libastra_path)
+    end
+    
+    push!(candidates, built_lib)
+    push!(candidates, "libastra.so")
+    return candidates
 end
```

### 2.2 `src/LowLevel.jl` の変更案
```diff
--- a/src/LowLevel.jl
+++ b/src/LowLevel.jl
@@ -3,6 +3,11 @@ module LowLevel
 using Libdl
 
+# Optional JLL loader
+@static if isfile(joinpath(@__DIR__, "..", "deps", "deps.jl"))
+    include(joinpath(@__DIR__, "..", "deps", "deps.jl"))
+end
+
 export set_library!,
        library_path,
```

### 2.3 `Project.toml` の変更案
```diff
--- a/Project.toml
+++ b/Project.toml
@@ -7,6 +7,7 @@ authors = ["Koh Hashimoto <koh.hashimoto@gmail.com>", "AstraToolbox contributors
 [deps]
+AstraToolbox_jll = "..." # UUID to be assigned upon Yggdrasil registration
 Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
 Libdl = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
 LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
@@ -14,6 +15,7 @@ Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
 SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
 
 [compat]
+AstraToolbox_jll = "2.4"
 Distributions = "0.25"
 SparseArrays = "1.11.0"
 julia = "1.11"
```

---

## 3. 互換性・回帰テスト手順

PR 提出時およびマージ後の実機受入テスト手順:

1. **環境変数の指定による JLL / Local ビルドの切り替えテスト**:
   ```bash
   # JLL 経由でのテスト
   julia --startup-file=no --project=. test/runtests.jl
   
   # ローカルビルド成果物を強制指定したテスト
   ASTRA_JULIA_LIB=/home/jov/git/prj/AstraToolbox.jl/deps/usr/lib/libastra.so \
       julia --startup-file=no --project=. test/runtests.jl
   ```
2. **テストスイートの通過確認**:
   - `AstraToolbox.jl/test/runtests.jl` の全 1,148 行におよぶ幾何・投影・再構成（CPU および CUDA）テストが双方で同様に PASS することを確認。
