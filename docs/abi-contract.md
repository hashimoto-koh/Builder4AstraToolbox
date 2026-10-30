# Julia C ABI 契約書 (abi-contract.md)

本書は `libastra` に組み込まれる Julia 用 C ABI bridge（`include/astra/julia_c_api.h` および `src/julia_c_api.cpp`）の仕様・契約を定義する文書である。

---

## 1. ABI 基本規約

### 1.1 リンケージとシンボル可視性
- 全関数は `extern "C"` リンケージを持ち、C++ 名前マングリングを行わない。
- シンボルプレフィックスはすべて `astra_julia_` で統一。
- 合計 114 個の関数が export される。

### 1.2 メモリモデルと所有権
- **借用バッファ (Borrowed Buffers)**:
  - Julia から渡される配列ポインタ（`volume`, `sinogram`, `angles`, `vectors`, `custom_filter` 等）はすべて呼び出し側（Julia）がメモリ所有権を保持する。
  - C ABI bridge 内で `BorrowedFloat32Memory` を通じて ASTRA の内部データ構造（`CFloat32VolumeData2D`, `CFloat32VolumeData3D` など）へラップし、関数終了時に破棄される。
  - 呼び出し中にメモリの解放・再割り当ては行われない。呼び出し完了まで Julia 側で GC による回収を防ぐ（Contiguous `Array{Float32}` の参照維持）。
- **配列レイアウト**:
  - Julia の標準である 1-based, 列優先（Column-Major）連続メモリ配置を前提とする。
  - `stride(A, 1) == 1` であることが Julia 側バインディング（`_check_array`）で検証される。
  - 2D volume: `(width, height)`
  - 2D sinogram: `(detector_count, angle_count)`
  - 3D volume: `(width, height, depth)`
  - 3D projection: `(detector_col_count, angle_count, detector_row_count)`
- **データ型**:
  - 画像データ・投影データ・幾何パラメータ・フィルタはすべて単精度浮動小数点（`Float32` / `float`）。
  - インデックス・寸法・反復回数などは `Cint`（`int` / `int32_t`）。
  - 疎行列のインデックスは `uint32_t*` (列インデックス) および `uint64_t*` (行開始オフセット)。

### 1.3 エラー処理規約
- **関数の戻り値**:
  - `int` 型を返す関数の多くは、成功時に `1`、失敗時に `0` を返す。
  - 診断・問合せ系関数（`has_cuda`, `get_gpu_count`, `get_gpu_index` 等）は状態または値を返す。
- **エラー情報の取得**:
  - C++ 側の例外は C ABI 境界を越えて漏出せず、`try { ... } catch (const std::exception& e)` によって捕捉される。
  - 捕捉されたエラー文字列はスレッドローカル変数に記録される。
  - Julia 側は失敗時（戻り値 0）に `const char* astra_julia_last_error()` を呼び出してメッセージを取得し、Julia 例外を送出する。

---

## 2. Export される全 114 シンボル一覧

### 2.1 ユーティリティ・診断・環境設定 (10 関数)
| シンボル名 | 説明 |
| :--- | :--- |
| `astra_julia_has_cuda` | CUDA サポートが有効化されてビルドされているか (1/0) |
| `astra_julia_has_feature` | 指定された機能文字列が有効か |
| `astra_julia_get_gpu_count` | 認識されている NVIDIA GPU 数 |
| `astra_julia_get_gpu_info` | 指定 GPU の名前・メモリ等の情報取得 |
| `astra_julia_set_gpu_index` | 使用する GPU インデックスの設定 |
| `astra_julia_get_gpu_index` | 現在設定されている GPU インデックスの取得 |
| `astra_julia_last_error` | 直前のエラーメッセージ文字列（スレッドローカル）取得 |
| `astra_julia_project_point_3d` | 3D 幾何において 3 次元座標を検出器平面へ投影 |
| `astra_julia_projected_bbox_3d` | 3D バウンディングボックスの投影領域計算 |
| `astra_julia_cuda_roi_select_2d_f32` | 2D ROI 選択マスクの抽出 |

### 2.2 ボリュームウィンドウ設定 (6 関数)
| シンボル名 | 説明 |
| :--- | :--- |
| `astra_julia_set_volume_window_2d` | 2D 再構成領域のウィンドウ（window min/max）設定 |
| `astra_julia_clear_volume_window_2d` | 2D ボリュームウィンドウのクリア（全体に戻す） |
| `astra_julia_get_volume_window_2d` | 2D ボリュームウィンドウの現在値取得 |
| `astra_julia_set_volume_window_3d` | 3D 再構成領域のウィンドウ設定 |
| `astra_julia_clear_volume_window_3d` | 3D ボリュームウィンドウのクリア |
| `astra_julia_get_volume_window_3d` | 3D ボリュームウィンドウの現在値取得 |

### 2.3 2D CPU プロジェクションおよび再構成 (42 関数)
| カテゴリ | シンボル名 |
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

### 2.4 2D CUDA プロジェクションおよび再構成 (24 関数)
| カテゴリ | シンボル名 |
| :--- | :--- |
| **CUDA FP** | `astra_julia_cuda_fp2d_parallel_line_f32`, `astra_julia_cuda_fp2d_parallel_vec_f32`, `astra_julia_cuda_fp2d_fanflat_f32`, `astra_julia_cuda_fp2d_fanflat_vec_f32` |
| **CUDA BP** | `astra_julia_cuda_bp2d_parallel_f32`, `astra_julia_cuda_bp2d_parallel_vec_f32`, `astra_julia_cuda_bp2d_fanflat_f32`, `astra_julia_cuda_bp2d_fanflat_vec_f32` |
| **CUDA FBP** | `astra_julia_cuda_fbp2d_parallel_f32`, `astra_julia_cuda_fbp2d_parallel_vec_f32`, `astra_julia_cuda_fbp2d_fanflat_f32`, `astra_julia_cuda_fbp2d_fanflat_vec_f32` |
| **CUDA SIRT** | `astra_julia_cuda_sirt2d_parallel_f32`, `astra_julia_cuda_sirt2d_parallel_vec_f32`, `astra_julia_cuda_sirt2d_fanflat_f32`, `astra_julia_cuda_sirt2d_fanflat_vec_f32` |
| **CUDA SART** | `astra_julia_cuda_sart2d_parallel_f32`, `astra_julia_cuda_sart2d_parallel_vec_f32`, `astra_julia_cuda_sart2d_fanflat_f32`, `astra_julia_cuda_sart2d_fanflat_vec_f32` |
| **CUDA CGLS** | `astra_julia_cuda_cgls2d_parallel_f32`, `astra_julia_cuda_cgls2d_parallel_vec_f32`, `astra_julia_cuda_cgls2d_fanflat_f32`, `astra_julia_cuda_cgls2d_fanflat_vec_f32` |
| **CUDA EM** | `astra_julia_cuda_em2d_parallel_f32` |
| **CUDA DART** | `astra_julia_cuda_dart_mask_2d_f32`, `astra_julia_cuda_dart_smoothing_2d_f32` |

### 2.5 3D CUDA プロジェクションおよび再構成 (32 関数)
| カテゴリ | シンボル名 |
| :--- | :--- |
| **CUDA 3D FP** | `astra_julia_cuda_fp3d_parallel_f32`, `astra_julia_cuda_fp3d_parallel_vec_f32`, `astra_julia_cuda_fp3d_cone_f32`, `astra_julia_cuda_fp3d_cone_vec_f32`, `astra_julia_cuda_fp3d_cyl_cone_vec_f32` |
| **CUDA 3D BP** | `astra_julia_cuda_bp3d_parallel_f32`, `astra_julia_cuda_bp3d_parallel_vec_f32`, `astra_julia_cuda_bp3d_cone_f32`, `astra_julia_cuda_bp3d_cone_vec_f32`, `astra_julia_cuda_bp3d_cyl_cone_vec_f32` |
| **CUDA 3D FDK** | `astra_julia_cuda_fdk3d_cone_f32`, `astra_julia_cuda_fdk3d_cone_vec_f32` |
| **CUDA 3D SIRT** | `astra_julia_cuda_sirt3d_parallel_f32`, `astra_julia_cuda_sirt3d_parallel_vec_f32`, `astra_julia_cuda_sirt3d_cone_f32`, `astra_julia_cuda_sirt3d_cone_vec_f32`, `astra_julia_cuda_sirt3d_cyl_cone_vec_f32` |
| **CUDA 3D CGLS** | `astra_julia_cuda_cgls3d_parallel_f32`, `astra_julia_cuda_cgls3d_parallel_vec_f32`, `astra_julia_cuda_cgls3d_cone_f32`, `astra_julia_cuda_cgls3d_cone_vec_f32`, `astra_julia_cuda_cgls3d_cyl_cone_vec_f32` |
| **CUDA 3D Composite** | `astra_julia_cuda_composite_fp3d_f32`, `astra_julia_cuda_composite_bp3d_f32` |
| **CUDA 3D DART** | `astra_julia_cuda_dart_mask_3d_f32`, `astra_julia_cuda_dart_smoothing_3d_f32` |

---

## 3. 受入・互換性テスト基準

1. **シンボル完全一致**:
   - `nm -D --defined-only libastra.so | grep " astra_julia_"` の出力が上記 114 個と完全に一致すること。
2. **C++ ABI 整合性**:
   - GCC 12 / C++17 でビルドされ、glibc 2.17+ / C++11 standard library ABI と整合すること。
3. **数値同一性**:
   - 同じ入力データに対し、現行の `deps/build.jl` でビルドされた `libastra.so` と JLL 版 `libastra.so` が計算機誤差（GPU 非決定性や浮動小数点丸め誤差の許容範囲内、相対誤差 $< 10^{-5}$）で同一の結果を返すこと。
