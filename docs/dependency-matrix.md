# Dependency Matrix (dependency-matrix.md)

This document specifies the build-time and runtime dependencies, toolchain requirements, and target platform matrix for `libastra` (ASTRA Toolbox + Julia C ABI).

---

## 1. Dynamic Shared Library Dependencies (ELF NEEDED)

Inspection results of the ELF dynamic section (`readelf -d`) from the native shared library (`libastra.so`):

| NEEDED Shared Library | Purpose | Origin / Resolution Strategy in JLL |
| :--- | :--- | :--- |
| `libcudart.so.12` | CUDA Runtime API | `CUDA_Runtime_jll` (CUDA 12) |
| `libcufft.so.11` | CUDA Fast Fourier Transform | `CUDA_Runtime_jll` / `CUDA_SDK_jll` (CUFFT) |
| `libstdc++.so.6` | C++ Standard Library | BinaryBuilder GCC toolchain (`CompilerSupportLibraries_jll`) |
| `libm.so.6` | Math Library | glibc |
| `libc.so.6` | C Standard Library | glibc |
| `ld-linux-x86-64.so.2` | Dynamic Linker | glibc |
| `libgcc_s.so.1` | GCC Runtime | BinaryBuilder GCC toolchain |

- **SONAME**: `libastra.so.0`
- **RPATH / RUNPATH**: Standard BinaryBuilder RPATH configuration (`$ORIGIN` resolution)

### 1.1 Key Findings Regarding External Dependencies
- **FFTW**: While upstream `configure.ac` checks for FFTW, the audit confirms `libastra.so` is not linked against external `libfftw3.so`. ASTRA relies on `libcufft` for GPU routines and internal algorithms for CPU routines.
- **XML**: ASTRA embeds TinyXML sources (`XMLConfig.cpp`, `XMLDocument.cpp`, `XMLNode.cpp`) directly in its source tree; no external `libxml2` dependency is needed.
- **Boost**: `libboost_unit_test_framework` is used solely for the upstream test suite and is not required for compiling `libastra.la` or linking `libastra.so`.
- **Python / MATLAB**: Configured with `--with-python=no --with-matlab=no`; no Python, NumPy, or MATLAB dependencies exist.

---

## 2. Toolchain Requirements

### 2.1 Build Tools
- **Autotools**: `autoconf` (>= 2.69), `automake`, `libtool`
  - Upstream requires running `build/linux/autogen.sh` to generate `configure` and Makefile templates.
- **Host C++ Compiler**: `g++` (C++17 support, GCC 10+).
- **CUDA Compiler**: `nvcc` (CUDA 12.x series).
  - Provided via `CUDA_SDK_jll` or official NVIDIA redistributable toolchain in BinaryBuilder.

---

## 3. Platform & GPU Architecture Strategy

### 3.1 Target Platforms
- **Platform Triplet**: `x86_64-linux-gnu` (glibc >= 2.17)
- **Supported Execution Environment**:
  - NVIDIA GPU present (Primary validation target: GeForce RTX 3090, `sm_86`)
  - NVIDIA Display Driver: >= 525.60.13 (CUDA 12.0+ compatible; primary host runs Driver 570.211.01)
  - **Distribution Boundary**: Exclusively CUDA-enabled JLL. CPU-only JLL or variant artifacts are excluded.

### 3.2 Compute Capabilities (SASS & PTX)
ASTRA Toolbox `configure.ac` supports `--with-cuda-compute=archs` (default `all-major`):
- `sm_50`, `sm_60`, `sm_70`, `sm_75`, `sm_80`, `sm_86`, `sm_89`, `sm_90`
- Plus `compute_90` PTX for forward compatibility with future hardware via JIT compilation.
- Total binary size is approximately 10–15 MB, well within standard artifact size thresholds.

---

## 4. BinaryBuilder / Yggdrasil Recipe Architecture

1. **Product Definition**:
   ```julia
   products = [
       LibraryProduct("libastra", :libastra)
   ]
   ```
2. **Dependencies**:
   - `BuildDependency(PackageSpec(name = "CUDA_SDK_jll", ...))`
   - `RuntimeDependency(PackageSpec(name = "CUDA_Runtime_jll"))`
   - `Dependency(PackageSpec(name = "CompilerSupportLibraries_jll"))`
3. **Build Script Flow**:
   - Acquire upstream source pinned to `bd0323e9b4b243ee90bca41341927b05e6e816c8`.
   - Apply unified diff patches (`darthelper.cu` index typo, `Makefile.in` object inclusion).
   - Inject Julia C ABI wrapper files into `include/astra/` and `src/`.
   - Run `autogen.sh`.
   - Run `./configure --prefix=${prefix} --host=${target} --with-cuda=${CUDA_HOME} --with-python=no --with-matlab=no --with-cuda-compute=all-major`.
   - Run `make -j${nproc} libastra.la`.
   - Install `.libs/libastra.so*` to `${libdir}`.
   - Clean up build-only SDK directories (`${prefix}/cuda`) to keep the published artifact minimal.
