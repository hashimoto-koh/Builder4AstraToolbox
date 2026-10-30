# Julia C ABI Contract (abi-contract.md)

This document defines the formal specifications, conventions, and contracts for the Julia C ABI bridge (`include/astra/julia_c_api.h` and `src/julia_c_api.cpp`) bundled within `libastra`.

---

## 1. ABI Conventions

### 1.1 Linkage and Symbol Visibility
- All wrapper functions have `extern "C"` linkage, avoiding C++ name mangling.
- All exported symbol names are prefixed with `astra_julia_`.
- Exactly 114 symbols are exported.

### 1.2 Memory Model and Ownership
- **Borrowed Buffers**:
  - Array pointers passed from Julia (`volume`, `sinogram`, `angles`, `vectors`, `custom_filter`, etc.) remain exclusively owned by the Julia caller.
  - The C ABI bridge wraps these pointers using `BorrowedFloat32Memory` into internal ASTRA data structures (`CFloat32VolumeData2D`, `CFloat32VolumeData3D`, etc.), which are destroyed upon function return.
  - No memory allocation or deallocation of caller buffers occurs inside the native layer. Callers must keep contiguous `Array{Float32}` buffers pinned/rooted for the duration of the call.
- **Array Layout**:
  - Expects standard Julia 1-based, column-major contiguous memory layouts (`stride(A, 1) == 1`).
  - 2D volume: `(width, height)`
  - 2D sinogram: `(detector_count, angle_count)`
  - 3D volume: `(width, height, depth)`
  - 3D projection: `(detector_col_count, angle_count, detector_row_count)`
- **Data Types**:
  - Image, projection data, geometric parameters, and filters use single-precision floating point (`Float32` / `float`).
  - Dimensions, iteration counts, and indices use `Cint` (`int` / `int32_t`).
  - Sparse matrix representations use `uint32_t*` (column indices) and `uint64_t*` (row start offsets).

### 1.3 Error Handling Contract
- **Return Codes**:
  - Functions returning `int` return `1` on success and `0` on failure.
  - Diagnostic functions (`has_cuda`, `get_gpu_count`, `get_gpu_index`, etc.) return values directly.
- **Exception Interception**:
  - Native C++ exceptions never cross the C ABI boundary; all top-level functions contain `try { ... } catch (const std::exception& e)` guards.
  - Caught error messages are stored in thread-local memory.
  - Julia bindings inspect `const char* astra_julia_last_error()` on failure (`0`) and raise corresponding Julia exceptions.

---

## 2. Complete Catalog of 114 Exported Symbols

### 2.1 Diagnostics, Configuration & Utilities (10 functions)
| Symbol Name | Description |
| :--- | :--- |
| `astra_julia_has_cuda` | Returns 1 if CUDA support was compiled in, 0 otherwise |
| `astra_julia_has_feature` | Checks if a named feature string is supported |
| `astra_julia_get_gpu_count` | Returns the number of detected NVIDIA GPUs |
| `astra_julia_get_gpu_info` | Queries GPU name, memory, and architecture information |
| `astra_julia_set_gpu_index` | Sets active CUDA GPU index |
| `astra_julia_get_gpu_index` | Gets currently configured CUDA GPU index |
| `astra_julia_last_error` | Returns the last thread-local error message string |
| `astra_julia_project_point_3d` | Projects a 3D coordinate onto detector plane |
| `astra_julia_projected_bbox_3d` | Computes detector bounding box of a 3D volume |
| `astra_julia_cuda_roi_select_2d_f32` | Extracts 2D ROI selection mask |

### 2.2 Volume Window Configuration (6 functions)
| Symbol Name | Description |
| :--- | :--- |
| `astra_julia_set_volume_window_2d` | Sets 2D volume reconstruction window (min/max bounds) |
| `astra_julia_clear_volume_window_2d` | Clears 2D volume window (resets to full volume) |
| `astra_julia_get_volume_window_2d` | Retrieves current 2D volume window coordinates |
| `astra_julia_set_volume_window_3d` | Sets 3D volume reconstruction window |
| `astra_julia_clear_volume_window_3d` | Clears 3D volume window |
| `astra_julia_get_volume_window_3d` | Retrieves current 3D volume window coordinates |

### 2.3 2D CPU Projection & Reconstruction (42 functions)
| Category | Symbol Names |
| :--- | :--- |
| **Parallel FP** | `astra_julia_fp2d_parallel_line_f32`, `astra_julia_fp2d_parallel_vec_line_f32`, `astra_julia_fp2d_parallel_linear_f32`, `astra_julia_fp2d_parallel_vec_linear_f32`, `astra_julia_fp2d_parallel_strip_f32`, `astra_julia_fp2d_parallel_vec_strip_f32`, `astra_julia_fp2d_parallel_distance_driven_f32`, `astra_julia_fp2d_parallel_vec_distance_driven_f32` |
| **Parallel BP** | `astra_julia_bp2d_parallel_line_f32`, `astra_julia_bp2d_parallel_vec_line_f32`, `astra_julia_bp2d_parallel_linear_f32`, `astra_julia_bp2d_parallel_vec_linear_f32`, `astra_julia_bp2d_parallel_strip_f32`, `astra_julia_bp2d_parallel_vec_strip_f32`, `astra_julia_bp2d_parallel_distance_driven_f32`, `astra_julia_bp2d_parallel_vec_distance_driven_f32` |
| **FanFlat FP** | `astra_julia_fp2d_fanflat_line_f32`, `astra_julia_fp2d_fanflat_vec_line_f32`, `astra_julia_fp2d_fanflat_strip_f32` |
| **FanFlat BP** | `astra_julia_bp2d_fanflat_line_f32`, `astra_julia_bp2d_fanflat_vec_line_f32`, `astra_julia_bp2d_fanflat_strip_f32` |
| **FBP** | `astra_julia_fbp2d_parallel_f32` |
| **SIRT** | `astra_julia_sirt2d_parallel_f32`, `astra_julia_sirt2d_parallel_vec_f32`, `astra_julia_sirt2d_fanflat_f32`, `astra_julia_sirt2d_fanflat_vec_f32` |
| **SART** | `astra_julia_sart2d_parallel_f32`, `astra_julia_sart2d_parallel_vec_f32`, `astra_julia_sart2d_fanflat_f32`, `astra_julia_sart2d_fanflat_vec_f32` |
| **CGLS** | `astra_julia_cgls2d_parallel_f32`, `astra_julia_cgls2d_parallel_vec_f32`, `astra_julia_cgls2d_fanflat_f32`, `astra_julia_cgls2d_fanflat_vec_f32` |
| **ART** | `astra_julia_art2d_parallel_f32`, `astra_julia_art2d_parallel_vec_f32`, `astra_julia_art2d_fanflat_f32`, `astra_julia_art2d_fanflat_vec_f32` |
| **Sparse Matrix** | `astra_julia_fp2d_sparse_matrix_f32`, `astra_julia_bp2d_sparse_matrix_f32`, `astra_julia_sirt2d_sparse_matrix_f32`, `astra_julia_sart2d_sparse_matrix_f32`, `astra_julia_cgls2d_sparse_matrix_f32`, `astra_julia_art2d_sparse_matrix_f32` |

### 2.4 2D CUDA Projection & Reconstruction (24 functions)
| Category | Symbol Names |
| :--- | :--- |
| **CUDA FP** | `astra_julia_cuda_fp2d_parallel_line_f32`, `astra_julia_cuda_fp2d_parallel_vec_f32`, `astra_julia_cuda_fp2d_fanflat_f32`, `astra_julia_cuda_fp2d_fanflat_vec_f32` |
| **CUDA BP** | `astra_julia_cuda_bp2d_parallel_f32`, `astra_julia_cuda_bp2d_parallel_vec_f32`, `astra_julia_cuda_bp2d_fanflat_f32`, `astra_julia_cuda_bp2d_fanflat_vec_f32` |
| **CUDA FBP** | `astra_julia_cuda_fbp2d_parallel_f32`, `astra_julia_cuda_fbp2d_parallel_vec_f32`, `astra_julia_cuda_fbp2d_fanflat_f32`, `astra_julia_cuda_fbp2d_fanflat_vec_f32` |
| **CUDA SIRT** | `astra_julia_cuda_sirt2d_parallel_f32`, `astra_julia_cuda_sirt2d_parallel_vec_f32`, `astra_julia_cuda_sirt2d_fanflat_f32`, `astra_julia_cuda_sirt2d_fanflat_vec_f32` |
| **CUDA SART** | `astra_julia_cuda_sart2d_parallel_f32`, `astra_julia_cuda_sart2d_parallel_vec_f32`, `astra_julia_cuda_sart2d_fanflat_f32`, `astra_julia_cuda_sart2d_fanflat_vec_f32` |
| **CUDA CGLS** | `astra_julia_cuda_cgls2d_parallel_f32`, `astra_julia_cuda_cgls2d_parallel_vec_f32`, `astra_julia_cuda_cgls2d_fanflat_f32`, `astra_julia_cuda_cgls2d_fanflat_vec_f32` |
| **CUDA EM** | `astra_julia_cuda_em2d_parallel_f32` |
| **CUDA DART** | `astra_julia_cuda_dart_mask_2d_f32`, `astra_julia_cuda_dart_smoothing_2d_f32` |

### 2.5 3D CUDA Projection & Reconstruction (32 functions)
| Category | Symbol Names |
| :--- | :--- |
| **CUDA 3D FP** | `astra_julia_cuda_fp3d_parallel_f32`, `astra_julia_cuda_fp3d_parallel_vec_f32`, `astra_julia_cuda_fp3d_cone_f32`, `astra_julia_cuda_fp3d_cone_vec_f32`, `astra_julia_cuda_fp3d_cyl_cone_vec_f32` |
| **CUDA 3D BP** | `astra_julia_cuda_bp3d_parallel_f32`, `astra_julia_cuda_bp3d_parallel_vec_f32`, `astra_julia_cuda_bp3d_cone_f32`, `astra_julia_cuda_bp3d_cone_vec_f32`, `astra_julia_cuda_bp3d_cyl_cone_vec_f32` |
| **CUDA 3D FDK** | `astra_julia_cuda_fdk3d_cone_f32`, `astra_julia_cuda_fdk3d_cone_vec_f32` |
| **CUDA 3D SIRT** | `astra_julia_cuda_sirt3d_parallel_f32`, `astra_julia_cuda_sirt3d_parallel_vec_f32`, `astra_julia_cuda_sirt3d_cone_f32`, `astra_julia_cuda_sirt3d_cone_vec_f32`, `astra_julia_cuda_sirt3d_cyl_cone_vec_f32` |
| **CUDA 3D CGLS** | `astra_julia_cuda_cgls3d_parallel_f32`, `astra_julia_cuda_cgls3d_parallel_vec_f32`, `astra_julia_cuda_cgls3d_cone_f32`, `astra_julia_cuda_cgls3d_cone_vec_f32`, `astra_julia_cuda_cgls3d_cyl_cone_vec_f32` |
| **CUDA 3D Composite** | `astra_julia_cuda_composite_fp3d_f32`, `astra_julia_cuda_composite_bp3d_f32` |
| **CUDA 3D DART** | `astra_julia_cuda_dart_mask_3d_f32`, `astra_julia_cuda_dart_smoothing_3d_f32` |

---

## 3. Acceptance & Verification Gates

1. **Symbol Parity Gate**:
   - `nm -D --defined-only libastra.so | grep " astra_julia_"` output must exactly match the 114 symbols listed above.
2. **C++ ABI Compatibility Gate**:
   - Compiled with GCC 10+ / C++17, compatible with glibc 2.17+ and libstdc++ C++11 dual ABI.
3. **Numerical Equivalence Gate**:
   - Given identical test inputs, numerical results between legacy local builds and JLL artifacts must match within strict tolerances (relative error $< 10^{-5}$ accounting for GPU floating-point non-determinism).
