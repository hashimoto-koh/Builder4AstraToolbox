# Build & Validation Specifications (build-validation.md)

This document establishes the build specifications, platform requirements, CUDA architecture strategy, and hardware acceptance criteria for `Builder4AstraToolbox`.

---

## 1. Single CUDA-Enabled JLL Policy

### 1.1 Exclusively CUDA-Enabled Distribution
- **Distribution Scope**: Only **CUDA-enabled JLL artifacts on Linux x86_64** are packaged and released.
- **Exclusion of CPU-Only Variants**: No CPU-only JLL package, CPU-only artifact, or CPU-only build variant is created.
- **Hardware Boundary**: Hosts without an NVIDIA GPU or driver are unsupported. Successful `dlopen` or execution on non-GPU systems is outside the project acceptance criteria.

### 1.2 Preservation of CPU Algorithms & Empirical Proof
- A CUDA-enabled `libastra.so` build embeds all native CPU 2D projection and reconstruction algorithms (Parallel/FanFlat FP/BP, FBP, SIRT, SART, CGLS, ART, SparseMatrix) alongside the CUDA kernels.
- **Empirical Validation**:
  On an NVIDIA GeForce RTX 3090 / CUDA 12.8 host, identical forward projection and backprojection outputs were verified using the same CUDA-enabled `libastra.so`:
  - `project(volume, geom; backend = cpu())`  -> `Float32[4.0 7.0; 6.0 3.0]`
  - `project(volume, geom; backend = cuda())` -> `Float32[4.0 7.0; 6.0 3.0]` (Identical)
  - `backproject(sino, geom; volume_size = (2, 2), backend = cpu())`  -> `Float32[7.0 11.0; 9.0 13.0]`
  - `backproject(sino, geom; volume_size = (2, 2), backend = cuda())` -> `Float32[7.0 11.0; 9.0 13.0]` (Identical)
- Therefore, a single CUDA-enabled JLL fully satisfies both `backend=cpu()` and `backend=cuda()` execution in `AstraToolbox.jl`.

---

## 2. Platform & Hardware Specifications

### 2.1 Target Platform
- **Target Triplet**: `x86_64-linux-gnu`
- **glibc Requirement**: >= 2.17
- **CUDA Toolkit Series**: CUDA 12.x (CUDA 12.0 through 12.8+)
- **NVIDIA Driver Requirement**: >= 525.60.13 (Validation host: Driver 570.211.01)
- **Primary Hardware Target**: NVIDIA GeForce RTX 3090 (`sm_86`)

### 2.2 CUDA Compute Capabilities & Binary Footprint
The BinaryBuilder recipe targets major SASS architectures:
- `sm_50` (Maxwell)
- `sm_60` (Pascal)
- `sm_70` (Volta)
- `sm_75` (Turing)
- `sm_80` (Ampere A100)
- `sm_86` (Ampere RTX 30xx, validation target)
- `sm_89` (Ada Lovelace RTX 40xx)
- `sm_90` (Hopper)
- `compute_90` PTX (Forward compatibility fallback for future hardware generations)

**Binary Footprint**:
With all major architectures included, the resulting `libastra.so` footprint is approximately 10–15 MB, well within BinaryBuilder's artifact limits.

---

## 3. Library Naming & Symbol Namespace

- **Shared Library Name**: `libastra.so` (SONAME: `libastra.so.0`)
  - Preserves upstream standard Autotools naming to minimize recipe complexity.
- **JLL Product Declaration**:
  ```julia
  products = [
      LibraryProduct("libastra", :libastra)
  ]
  ```
- **Namespace Isolation**:
  - JLL artifacts are unpacked into dedicated artifact directories (`~/.julia/artifacts/<hash>/lib/`) and loaded via absolute paths, preventing conflicts with any system-installed ASTRA.
  - Runtime environment overrides via `ASTRA_JULIA_LIB` and `LowLevel.set_library!(path)` remain supported.

---

## 4. Source & Patch Management

1. **Upstream Source**:
   - `https://github.com/astra-toolbox/astra-toolbox.git`
   - Pinned Commit: `bd0323e9b4b243ee90bca41341927b05e6e816c8`
   - Downloaded dynamically via BinaryBuilder `GitSource` without vendoring upstream trees into Git.
2. **Wrapper Sources**:
   - `bundled/wrapper/include/astra/julia_c_api.h`
   - `bundled/wrapper/src/julia_c_api.cpp`
   - Maintained within this repository to serve as the build input for the Yggdrasil recipe.
3. **Upstream Unified Diff Patches**:
   - `bundled/patches/0001-fix-darthelper-typo.patch`: Corrects index reference typo (`o3+1` -> `o2+1`) in `cuda/2d/darthelper.cu`.
   - `bundled/patches/0002-add-julia-c-api-to-makefile.patch`: Adds `src/julia_c_api.lo` to `build/linux/Makefile.in`.

---

## 5. Acceptance Verification Criteria

1. **Static ABI Verification**:
   - All 114 `astra_julia_*` symbols must be exported exactly.
   - Dynamic dependencies must be restricted strictly to CUDA runtime (`libcudart`), CUDA FFT (`libcufft`), and standard C++ libraries. No external FFTW or XML2 dependencies.
2. **Device Discovery**:
   - On an RTX 3090 host:
     - `astra_julia_has_cuda() == 1`
     - `astra_julia_get_gpu_count() >= 1`
3. **Numerical Equivalence**:
   - Output arrays between CPU and CUDA algorithms must match within floating-point tolerance (relative error $< 10^{-5}$).

---

## 6. Hardware Acceptance Test Log

- **Date**: 2026-10-30
- **Host Hardware**: NVIDIA GeForce RTX 3090, Driver 570.211.01, CUDA 12.8, Julia 1.11.9
- **Test Scripts**: `scripts/inspect_abi.sh`, `scripts/test_products.jl`, `test/runtests.jl`

### 6.1 ABI & Dynamic Linkage (`scripts/inspect_abi.sh`)
- `NEEDED`: `libcudart.so.12`, `libcufft.so.11`, `libstdc++.so.6`, `libm.so.6`, `libc.so.6`, `ld-linux-x86-64.so.2`, `libgcc_s.so.1` (Passed)
- `SONAME`: `libastra.so.0` (Passed)
- `Exported Symbol Count`: 114 / 114 (100% Match, Passed)
- `Wrapper Source Consistency`: Bitwise identical to `AstraToolbox.jl/deps/wrapper/` (Passed)

### 6.2 Direct C ABI Numerical Verification (`scripts/test_products.jl`)
- `astra_julia_has_cuda`: 1 (True)
- `astra_julia_get_gpu_count`: 1 (True)
- 2D Parallel FP (CPU vs CUDA):
  - CPU: `Float32[3.0 6.0; 7.0 4.0]`
  - CUDA: `Float32[3.0 6.0; 7.0 4.0]`
  - Max Absolute Difference: `0.0` (Passed)
- 2D Parallel BP (CPU vs CUDA):
  - CPU: `Float32[7.0 9.0; 11.0 13.0]`
  - CUDA: `Float32[7.0 9.0; 11.0 13.0]`
  - Max Absolute Difference: `0.0` (Passed)

### 6.3 Automated Test Suite (`test/runtests.jl`)
- 15 / 15 tests PASSED (Elapsed time: 2.0s)
