# Implementation Audit Record (inventory.md)

This document records the audit findings of the existing native build in `AstraToolbox.jl`, upstream ASTRA Toolbox, and dependency requirements for migrating to BinaryBuilder / Yggdrasil distribution (`AstraToolbox_jll`).

---

## 1. Audited Revisions

### 1.1 AstraToolbox.jl
- **Repository Path**: `/home/jov/git/prj/AstraToolbox.jl` (read-only reference; no modifications permitted)
- **Git Commit**: `caf2d0e3065cde52368bf5c63308f3363a902724`
- **Branch**: `master` (synchronized with `origin/master`)
- **License**: GPL-3.0-or-later

### 1.2 Upstream ASTRA Toolbox
- **Repository**: `https://github.com/astra-toolbox/astra-toolbox.git`
- **Fixed Commit**: `bd0323e9b4b243ee90bca41341927b05e6e816c8` (matches `DEFAULT_ASTRA_REF` in AstraToolbox.jl `deps/build.jl`)
- **License**: GPL-3.0-or-later
- **Authors**: imec-Vision Lab (University of Antwerp) & CWI (Amsterdam)

---

## 2. Analysis of Existing deps/build.jl Pipeline

`AstraToolbox.jl/deps/build.jl` compiles the native library locally on the user's host machine via the following sequential steps:

1. **CUDA Root Detection (`detect_cuda_root`)**:
   - Inspects environment variables `ASTRATOOLBOXJL_CUDA`, `CUDA_ROOT`, `CUDA_HOME`.
   - Checks `/usr/local/cuda`.
   - Locates `nvcc` via `Sys.which("nvcc")` and infers the parent toolkit directory.
   - **Fails with an error if no CUDA toolkit is found** (does not fall back to CPU-only build).
2. **Upstream Source Acquisition (`acquire_astra_source`)**:
   - Clones upstream repository into `deps/work/astra-toolbox`.
   - Checks out pinned commit `bd0323e9b4b243ee90bca41341927b05e6e816c8`.
3. **Upstream Source Patching (`patch_upstream_sources`)**:
   - Corrects index reference typo in `cuda/2d/darthelper.cu`:
     - Before: `d[o2 - 1] != d[o2] ||                  d[o3 + 1] != d[o2] ||`
     - After:  `d[o2 - 1] != d[o2] ||                  d[o2 + 1] != d[o2] ||`
4. **Julia C ABI Wrapper Injection (`install_wrapper_files`)**:
   - Copies `deps/wrapper/include/astra/julia_c_api.h` to `include/astra/julia_c_api.h`.
   - Copies `deps/wrapper/src/julia_c_api.cpp` to `src/julia_c_api.cpp`.
5. **Makefile.in Patching (`patch_makefile`)**:
   - Appends `\tsrc/julia_c_api.lo \` immediately after `src/Globals.lo \` in `build/linux/Makefile.in`.
6. **Autotools Compilation (`build_astra`)**:
   - Navigates to `build/linux`.
   - Executes `./autogen.sh`.
   - Executes `./configure --with-cuda=$cuda_root --with-python=no`.
   - Runs `make -j8 libastra.la`.
7. **Installation and deps.jl Generation (`install_library`)**:
   - Copies `build/linux/.libs/libastra.so` to `deps/usr/lib/libastra.so`.
   - Generates `deps/deps.jl` defining `const libastra = "/home/jov/git/prj/AstraToolbox.jl/deps/usr/lib/libastra.so"`.

---

## 3. Julia-Side Library Resolution & Invocation Architecture

### 3.1 Dynamic Library Resolution (`src/LowLevel.jl`, `src/lowlevel_common.jl`)
- When `deps/deps.jl` exists, `LowLevel.jl` includes it to define `const libastra`.
- `library_path()` resolves the library path in the following priority:
  1. Environment variable `ASTRA_JULIA_LIB`
  2. `libastra` from `deps.jl`, falling back to `deps/usr/lib/libastra.so`
  3. System library `"libastra.so"`
- Callers can override the active library path at runtime via `set_library!(path)`.
- `_libhandle()` calls `Libdl.dlopen(library_path())`, and individual binding functions resolve symbols dynamically via `Libdl.dlsym(lib, :astra_julia_...)` before invoking `ccall`.

### 3.2 Error Handling Contract
- C ABI return codes:
  - Success: `1`
  - Failure: `0`
- On failure, C++ exceptions are caught internally and saved in thread-local storage.
- Julia bindings query `const char* astra_julia_last_error()` via `LowLevel.last_error()` and throw corresponding Julia exceptions (`ErrorException`, etc.).

---

## 4. Yggdrasil & General Registry Survey

- **Yggdrasil (`JuliaPackaging/Yggdrasil`)**:
  - No existing recipes under `A/` or elsewhere match `AstraToolbox` or `Astra`.
  - Code search confirms that the upstream ASTRA Toolbox has not been contributed to Yggdrasil yet.
- **General Registry (`JuliaRegistries/General`)**:
  - Neither `AstraToolbox_jll`, `ASTRA_jll`, nor `libastra_jll` are registered.
- **Conclusion**:
  - The name `AstraToolbox_jll` has zero naming conflict and can be used directly.
  - Building ASTRA C++ / CUDA along with the Julia C ABI wrapper as a single unified JLL artifact is the cleanest and most maintainable architecture.

---

## 5. Licensing and Redistribution Compliance

- **Upstream ASTRA Toolbox**: GNU General Public License v3.0 or later (GPL-3.0-or-later).
- **AstraToolbox.jl / Wrapper**: GPL-3.0-or-later.
- **CUDA Runtime / CUFFT**: Distributed under the NVIDIA CUDA Toolkit Software License Agreement. Prebuilt redistributable libraries available through official Yggdrasil packages (`CUDA_Runtime_jll`).
- **Attribution & Disclaimer**:
  - Upstream copyright notices and academic citations (Optics Express 2016, Ultramicroscopy 2015) are documented in `THIRD_PARTY_NOTICES.md`.
  - Clear disclaimers stating this is an independent unofficial community packaging effort are published prominently.
