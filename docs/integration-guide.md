# AstraToolbox.jl Integration & Migration Guide (integration-guide.md)

This document outlines the proposed loader modifications, PR diff design, and verification procedures for integrating `AstraToolbox_jll` into `AstraToolbox.jl`.
*Note: `/home/jov/git/prj/AstraToolbox.jl` is a read-only reference repository. No direct edits are performed from this builder repository. All diffs below are prepared for future upstream PR submission.*

---

## 1. Integration Principles

1. **Complete Public API Preservation**:
   - `LowLevel.set_library!(path)`
   - `LowLevel.library_path()`
   - `LowLevel.has_cuda()`
   - `LowLevel.get_gpu_info()`
   - `LowLevel.last_error()`
   - High-level Julia interfaces (`project`, `backproject`, `reconstruct`, `fbp`, `sirt`, etc.) remain 100% unchanged.
2. **Library Resolution Precedence Contract**:
   Library resolution precedence is maintained and extended:
   1. `ENV["ASTRA_JULIA_LIB"]` (Highest priority override for custom/developer builds)
   2. `AstraToolbox_jll.libastra_path` (JLL artifact path, newly introduced)
   3. `libastra` from `deps/deps.jl` (Legacy local build output)
   4. System library `"libastra.so"`
3. **Phased Migration**:
   - In the initial integration PR, `deps/build.jl` is preserved alongside JLL loading.
   - After sufficient community validation, local building will be deprecated in favor of precompiled JLL binaries.

---

## 2. Proposed Changes to AstraToolbox.jl (PR Diff)

### 2.1 `src/lowlevel_common.jl` Diff
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

### 2.2 `src/LowLevel.jl` Diff
```diff
--- a/src/LowLevel.jl
+++ b/src/LowLevel.jl
@@ -3,6 +3,11 @@ module LowLevel
 using Libdl
 
+# Optional legacy local deps loader
+@static if isfile(joinpath(@__DIR__, "..", "deps", "deps.jl"))
+    include(joinpath(@__DIR__, "..", "deps", "deps.jl"))
+end
+
 export set_library!,
        library_path,
```

### 2.3 `Project.toml` Diff
```diff
--- a/Project.toml
+++ b/Project.toml
@@ -7,6 +7,7 @@ authors = ["Koh Hashimoto <koh.hashimoto@gmail.com>", "AstraToolbox contributors
 [deps]
+AstraToolbox_jll = "..." # UUID assigned upon Yggdrasil registration
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

## 3. Regression & Compatibility Testing Procedure

Verification steps once `AstraToolbox_jll` is published:

1. **Switching Between JLL and Local Build**:
   ```bash
   # Test using JLL artifact
   julia --startup-file=no --project=. test/runtests.jl
   
   # Test forcing legacy local build via environment variable override
   ASTRA_JULIA_LIB=/home/jov/git/prj/AstraToolbox.jl/deps/usr/lib/libastra.so \
       julia --startup-file=no --project=. test/runtests.jl
   ```
2. **Test Suite Verification**:
   - Ensure all 1,148 lines of `AstraToolbox.jl/test/runtests.jl` (including 2D/3D CPU and CUDA geometries, projectors, backprojectors, and reconstruction solvers) pass identically under both modes.
