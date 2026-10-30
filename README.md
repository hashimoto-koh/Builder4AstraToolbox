# Builder4AstraToolbox

`Builder4AstraToolbox` manages the build recipes, patches, Julia C ABI wrapper, and verification assets for building the native C++/CUDA backend shared library (`libastra`) of [AstraToolbox.jl](https://github.com/hashimoto-koh/AstraToolbox.jl) using [BinaryBuilder.jl](https://github.com/JuliaPackaging/BinaryBuilder.jl), ultimately packaging and distributing it as the official JLL package `AstraToolbox_jll` on [Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil).

This project is an unofficial packaging pipeline for [AstraToolbox.jl](https://github.com/hashimoto-koh/AstraToolbox.jl), interfacing with the high-performance C++/CUDA reconstruction engines of the upstream [ASTRA Toolbox](https://github.com/astra-toolbox/astra-toolbox).

> [!NOTE]
> This project is **not** affiliated with, endorsed by, or maintained by imec-Vision Lab, the University of Antwerp, CWI (Centrum Wiskunde & Informatica), or the upstream ASTRA Toolbox contributors.
>
> The foundational ASTRA Toolbox tomographic reconstruction architecture and GPU algorithms were developed by imec-Vision Lab (University of Antwerp) and CWI (Amsterdam), and are distributed under the GNU General Public License v3.0 or later (GPL-3.0-or-later). We express our deep respect and sincere gratitude to the original authors, maintainers, and contributors for creating and sustaining ASTRA Toolbox as an outstanding open-source tomographic reconstruction platform.

---

## Purpose

Previously, using `AstraToolbox.jl` required compiling the native ASTRA backend locally via `deps/build.jl`, necessitating a local CUDA development toolkit, `nvcc` compiler, and GNU Autotools on the user's host machine.

The goal of this repository is to build reproducible, relocatable binaries for `libastra` and submit the build recipe to the official Julia community build tree [Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil). This enables distributing precompiled binaries as `AstraToolbox_jll`, allowing Julia users to run both CPU and GPU tomographic reconstruction algorithms seamlessly with only an appropriate NVIDIA driver installed—without requiring a local CUDA development toolkit, host compiler, or build tools.

> [!NOTE]
> **Naming Distinctions**:
> - `Builder4AstraToolbox`: This repository (manages build recipes, patches, wrapper shims, verification test suites, and migration specifications).
> - `AstraToolbox_jll`: The auto-generated Julia binary wrapper package created and published by BinaryBuilder / Yggdrasil.
> - `AstraToolbox.jl`: The high-level Julia tomographic reconstruction package providing public APIs, type systems, and user interfaces.

---

## Architectural Principle: Single CUDA-Enabled JLL

- **Distribution Target**: Only **CUDA-enabled JLL artifacts on Linux x86_64** are built and distributed. CPU-only JLL variants or CPU-only artifacts are not created.
- **Full CPU Algorithm Preservation**: ASTRA's CPU 2D algorithms (Parallel/FanFlat FP/BP, FBP, SIRT, SART, CGLS, ART, SparseMatrix) are fully built and embedded inside the CUDA-enabled `libastra.so`. Julia callers can select either `backend=cpu()` or `backend=cuda()` from the exact same library.
- **Hardware Requirement**: Execution on hosts without an NVIDIA GPU or driver is unsupported.

---

## Repository Layout

```text
Builder4AstraToolbox/
├── .github/
│   └── workflows/
│       └── ci.yml             # GitHub Actions CI for recipe validation
├── bundled/                   # Yggdrasil-compliant bundled source tree (DirectorySource)
│   ├── COPYING                # Wrapper GPL-3.0 license
│   ├── patches/               # Upstream build patches
│   │   ├── 0001-fix-darthelper-typo.patch
│   │   └── 0002-add-julia-c-api-to-makefile.patch
│   └── wrapper/               # Julia C ABI bridge source files
│       ├── include/astra/
│       │   └── julia_c_api.h
│       └── src/
│           └── julia_c_api.cpp
├── docs/                      # Technical specifications and design documents
│   ├── inventory.md           # Audit of existing build, source refs, and APIs
│   ├── abi-contract.md        # C ABI contract and full 114 exported symbol catalog
│   ├── dependency-matrix.md   # Dynamic link dependencies and toolchain matrix
│   ├── build-validation.md    # Build validation specs and hardware acceptance test log
│   ├── release-process.md     # Yggdrasil release workflow and ABI versioning
│   └── integration-guide.md   # AstraToolbox.jl integration and PR migration plan
├── patches/                   # Repository-level integration patches
│   ├── README.md              # Patch documentation and instructions
│   └── astra_toolbox_jl_integration.patch  # Standalone patch for AstraToolbox.jl
├── platforms/
│   └── cuda.jl                # Official Yggdrasil CUDA platform helper
├── products/                  # Built BinaryBuilder artifacts (.tar.gz and extracted)
│   ├── AstraToolbox.v2.4.0.x86_64-linux-gnu-cuda+12.4.tar.gz
│   └── extracted/             # Extracted library for immediate test suite execution
├── scripts/
│   ├── inspect_abi.sh         # Dynamic section (NEEDED) and 114 symbol audit script
│   └── test_products.jl       # Direct C ABI verification (CPU vs CUDA numerical equivalence)
├── sources/                   # Source integrity verification
│   ├── manifest.toml          # Pinning cryptographic SHA256 checksums
│   └── verify_sources.jl      # Automated SHA256 verification script
├── test/
│   └── runtests.jl            # Master automated verification test suite
├── yggdrasil/                 # Yggdrasil submission staging directory
│   ├── README.md              # Yggdrasil PR submission guide
│   └── A/AstraToolbox/        # Exact tree ready for Yggdrasil PR
│       ├── build_tarballs.jl
│       └── bundled/
├── build_tarballs.jl          # BinaryBuilder.jl build recipe
├── LICENSE                    # GNU General Public License v3.0 (GPL-3.0-or-later)
├── Project.toml               # Project dependencies (BinaryBuilder v0.6+)
├── README.md                  # Master documentation
└── THIRD_PARTY_NOTICES.md     # Upstream notices, attributions, and academic citations
```

---

## Testing & Verification

Run the full automated test suite on an NVIDIA GPU host:

```bash
# Run all automated tests (ABI inspection, symbol audit, direct C ABI numerical equivalence)
julia --startup-file=no --project=. test/runtests.jl

# Inspect shared library NEEDED, SONAME, and all 114 exported symbols
./scripts/inspect_abi.sh

# Run direct C ABI CPU vs CUDA numerical equivalence test
julia --startup-file=no --project=. scripts/test_products.jl
```

---

## CUDA Support and Hardware Compatibility Matrix

`libastra.so` dynamically links only against `libcudart.so` and `libcufft.so` (provided by `CUDA_Runtime_jll`). The CUDA Driver library (`libcuda.so`) is supplied by the host system at runtime.

### Supported Architectures (SASS + PTX)
| Architecture | Compute Capability | Target GPUs | Generation Mode |
|---|---|---|---|
| Maxwell | `sm_50` | GTX 750, GTX 9xx | SASS |
| Pascal | `sm_60` | GP100, P100 | SASS |
| Volta | `sm_70` | Titan V, V100 | SASS |
| Turing | `sm_75` | RTX 2080, T4 | SASS |
| Ampere | `sm_80` | A100 | SASS |
| Ampere | `sm_86` | RTX 3090 (Primary test hardware), RTX 3080 | SASS |
| Ada Lovelace | `sm_89` | RTX 4090, RTX 4080, L40 | SASS |
| Hopper | `sm_90` | H100 | SASS |
| Forward Compatibility | `compute_90` | Future GPU architectures | PTX JIT compilation |

- **Host Driver Requirement**: NVIDIA Linux display driver >= 525.60.13 (CUDA 12.x compatible).
- **Host Compiler Requirement**: None. No local `nvcc` or CUDA Toolkit is required to run `AstraToolbox.jl` with `AstraToolbox_jll`.

---

## License & Academic Attribution

- **License**: Distributed under the [GNU General Public License v3.0 or later (GPL-3.0-or-later)](LICENSE).
- **Attribution**: When using ASTRA Toolbox or `AstraToolbox.jl` in scientific research, please cite the foundational publications:
  1. W. van Aarle et al., *"Fast and Flexible X-ray Tomography Using the ASTRA Toolbox"*, **Optics Express**, 24(22), 25129–25147, 2016. [DOI: 10.1364/OE.24.025129](https://doi.org/10.1364/OE.24.025129)
  2. W. van Aarle et al., *"The ASTRA Toolbox: A platform for advanced algorithm development in electron tomography"*, **Ultramicroscopy**, 157, 35–47, 2015. [DOI: 10.1016/j.ultramic.2015.05.002](https://doi.org/10.1016/j.ultramic.2015.05.002)
