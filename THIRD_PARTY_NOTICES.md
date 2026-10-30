# Third-Party Notices & Attribution

This repository, `Builder4AstraToolbox`, builds and distributes the native `libastra` library and Julia C ABI bridge for `AstraToolbox.jl`. The resulting software is distributed under the GNU General Public License v3.0 or later (GPL-3.0-or-later).

---

## 1. Upstream Project: ASTRA Toolbox

- **Upstream Repository**: <https://github.com/astra-toolbox/astra-toolbox>
- **Website & Documentation**: <https://www.astra-toolbox.com/>
- **Upstream Copyright**:
  - Copyright (c) 2010–2024, imec Vision Lab, University of Antwerp (<https://visielab.uantwerpen.be/>)
  - Copyright (c) 2014–2024, CWI (Centrum Wiskunde & Informatica), Amsterdam (<https://www.cwi.nl/>)
- **Upstream License**: GNU General Public License v3.0 or later (GPL-3.0-or-later)
- **Fixed Upstream Revision**: `bd0323e9b4b243ee90bca41341927b05e6e816c8`

### Disclaimer of Affiliation
This project is an independent community packaging effort for the Julia programming language ecosystem. It is **not** officially affiliated with, endorsed by, or maintained by imec-Vision Lab, the University of Antwerp, CWI, or the upstream ASTRA Toolbox developers.

### Academic Citations
When using the ASTRA Toolbox in scientific publications, please cite the following original papers:

1. **General Architecture and 2D/3D Toolbox**:
   > W. van Aarle, W. J. Palenstijn, J. Cant, E. Janssens, F. Bleichrodt, A. Dabravolski, J. De Beenhouwer, K. J. Batenburg, and J. Sijbers,  
   > *"Fast and Flexible X-ray Tomography Using the ASTRA Toolbox"*,  
   > **Optics Express**, vol. 24, no. 22, pp. 25129–25147, 2016.  
   > DOI: [10.1364/OE.24.025129](https://doi.org/10.1364/OE.24.025129)

2. **Electron Tomography & Advanced Algorithms**:
   > W. van Aarle, W. J. Palenstijn, J. De Beenhouwer, T. Altantzis, S. Bals, K. J. Batenburg, and J. Sijbers,  
   > *"The ASTRA Toolbox: A platform for advanced algorithm development in electron tomography"*,  
   > **Ultramicroscopy**, vol. 157, pp. 35–47, 2015.  
   > DOI: [10.1016/j.ultramic.2015.05.002](https://doi.org/10.1016/j.ultramic.2015.05.002)

---

## 2. Julia C ABI Wrapper

- **Copyright**: Copyright (c) 2026, AstraToolbox contributors
- **License**: GNU General Public License v3.0 or later (GPL-3.0-or-later)
- **Source**: `wrapper/include/astra/julia_c_api.h` and `wrapper/src/julia_c_api.cpp`
- **Modifications to Upstream**:
  - Julia C ABI functions (`astra_julia_*`) added to provide a lightweight zero-copy interface for `AstraToolbox.jl`.
  - Fix for 4-connected mask index typo in `cuda/2d/darthelper.cu` (`patches/0001-fix-darthelper-typo.patch`).
  - Inclusion of `julia_c_api.lo` in `build/linux/Makefile.in` (`patches/0002-add-julia-c-api-to-makefile.patch`).

---

## 3. NVIDIA CUDA Toolkit & Runtime

- Binary packages link dynamically against CUDA Runtime (`libcudart`) and CUDA FFT (`libcufft`).
- CUDA libraries and headers are provided under the NVIDIA CUDA Toolkit Software License Agreement.
