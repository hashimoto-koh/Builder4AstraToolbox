# Patches Directory (`patches/`)

This directory contains repository-level integration patches and references.

## Contents

- `astra_toolbox_jl_integration.patch`:
  Standalone unified diff patch for integrating the official `AstraToolbox_jll` package into [AstraToolbox.jl](https://github.com/hashimoto-koh/AstraToolbox.jl).
  It updates `Project.toml` and `src/lowlevel_common.jl` while maintaining 100% backward compatibility and falling back to local source builds (`deps/build.jl`).

## Build Patches for Upstream ASTRA

In accordance with Yggdrasil's `DirectorySource("./bundled")` packaging convention, all build-time patches applied to upstream ASTRA Toolbox are maintained inside `bundled/patches/`:

- `bundled/patches/0001-fix-darthelper-typo.patch`:
  Fixes a typo in `cuda/2d/darthelper.cu` (`d[o3 + 1]` -> `d[o2 + 1]`) matching the 4-connected mask condition.
- `bundled/patches/0002-add-julia-c-api-to-makefile.patch`:
  Adds `src/julia_c_api.lo` to `build/linux/Makefile.in` to compile the Julia C ABI bridge directly into `libastra.so`.
