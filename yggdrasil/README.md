# Yggdrasil Recipe Staging (`yggdrasil/`)

This directory contains the exact directory structure and recipe ready for submission to [JuliaPackaging/Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil).

---

## Directory Structure

```text
yggdrasil/
└── A/
    └── AstraToolbox/
        ├── build_tarballs.jl
        └── bundled/
            ├── COPYING
            ├── patches/
            │   ├── 0001-fix-darthelper-typo.patch
            │   └── 0002-add-julia-c-api-to-makefile.patch
            └── wrapper/
                ├── include/
                │   └── astra/
                │       └── julia_c_api.h
                └── src/
                    └── julia_c_api.cpp
```

---

## Instructions for Submitting to Yggdrasil

1. **Fork and Clone Yggdrasil**:
   ```bash
   git clone git@github.com:<your-username>/Yggdrasil.git
   cd Yggdrasil
   git checkout -b astra-toolbox-jll-initial
   ```

2. **Copy the Staged Recipe**:
   ```bash
   # From your Builder4AstraToolbox repository:
   cp -r /path/to/Builder4AstraToolbox/yggdrasil/A/AstraToolbox A/
   ```

3. **Verify Locally (Optional)**:
   ```bash
   # In the root of Yggdrasil:
   julia --project=. A/AstraToolbox/build_tarballs.jl --verbose
   ```

4. **Commit and Push**:
   ```bash
   git add A/AstraToolbox
   git commit -m "[AstraToolbox] Initial recipe for libastra (v2.4.0)"
   git push origin astra-toolbox-jll-initial
   ```

5. **Open a Pull Request**:
   - Open a PR against `JuliaPackaging/Yggdrasil:master`.
   - Provide summary:
     - Project: ASTRA Toolbox C++/CUDA library with Julia C ABI bridge (`AstraToolbox.jl`).
     - Upstream commit: `bd0323e9b4b243ee90bca41341927b05e6e816c8` (GPL-3.0-or-later).
     - Target platform: Linux x86_64, CUDA 12 series (`libcudart.so.12`, `libcufft.so`).
     - Exported library product: `libastra.so` providing 114 `astra_julia_*` symbols.
