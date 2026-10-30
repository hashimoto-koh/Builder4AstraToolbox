# Upstream Unified Diff Patches (patches/README.md)

This directory contains unified diff patches applied against the upstream ASTRA Toolbox repository (commit: `bd0323e9b4b243ee90bca41341927b05e6e816c8`).

---

## 1. `0001-fix-darthelper-typo.patch`
- **Target File**: `cuda/2d/darthelper.cu`
- **Purpose**: Corrects an array index reference typo in the 4-connected mask kernel.
- **Background**:
  The original code referenced `d[o3 + 1]` in the 4-connected evaluation branch. However, scanning the right-hand neighboring pixel requires `o2 + 1`, not `o3 + 1`.
- **Origin**: Extracted from `AstraToolbox.jl/deps/build.jl` (`patch_upstream_sources()`).

---

## 2. `0002-add-julia-c-api-to-makefile.patch`
- **Target File**: `build/linux/Makefile.in`
- **Purpose**: Appends `src/julia_c_api.lo` to `BASE_OBJECTS` for building `libastra.la`.
- **Background**:
  Enables the Autotools build system to compile the Julia C ABI wrapper implementation (`src/julia_c_api.cpp`) and bundle it directly into `libastra.so`.
- **Origin**: Extracted from `AstraToolbox.jl/deps/build.jl` (`patch_makefile()`).
