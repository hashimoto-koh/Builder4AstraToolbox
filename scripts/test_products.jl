#!/usr/bin/env julia
# scripts/test_products.jl - Direct C ABI verification of libastra.so

using Libdl
using Test

const ARTIFACT_LIB = normpath(joinpath(@__DIR__, "..", "products", "extracted", "lib", "libastra.so"))
const FALLBACK_LIB = "/home/jov/git/prj/AstraToolbox.jl/deps/usr/lib/libastra.so"
const DEFAULT_LIB = isfile(ARTIFACT_LIB) ? ARTIFACT_LIB : FALLBACK_LIB
const libpath = length(ARGS) >= 1 ? ARGS[1] : get(ENV, "ASTRA_JULIA_LIB", DEFAULT_LIB)

println("=== Testing libastra C ABI ===")
println("Library path: ", libpath)

@test isfile(libpath)
lib = Libdl.dlopen(libpath)
@test lib != C_NULL

# 1. Diagnostics & Features
println("\n--- 1. Diagnostic Checks ---")
has_cuda_sym = Libdl.dlsym(lib, :astra_julia_has_cuda)
has_cuda = ccall(has_cuda_sym, Cint, ())
println("astra_julia_has_cuda: ", has_cuda)
@test has_cuda == 1

get_gpu_count_sym = Libdl.dlsym(lib, :astra_julia_get_gpu_count)
gpu_count = ccall(get_gpu_count_sym, Cint, ())
println("astra_julia_get_gpu_count: ", gpu_count)
@test gpu_count >= 1

last_error_sym = Libdl.dlsym(lib, :astra_julia_last_error)
last_err_ptr = ccall(last_error_sym, Cstring, ())
println("Initial last_error: '", unsafe_string(last_err_ptr), "'")

# 2. 2D CPU Parallel Forward & Backprojection
println("\n--- 2. 2D CPU Parallel Line FP / BP ---")
fp2d_cpu_sym = Libdl.dlsym(lib, :astra_julia_fp2d_parallel_line_f32)
bp2d_cpu_sym = Libdl.dlsym(lib, :astra_julia_bp2d_parallel_line_f32)

vol_cpu = Float32[1.0 2.0; 3.0 4.0] # 2x2
angles = Float32[0.0, Float32(π / 2)] # 2 angles
sino_cpu = zeros(Float32, 2, 2) # 2 detectors, 2 angles

# int astra_julia_fp2d_parallel_line_f32(vol_w, vol_h, angle_cnt, det_cnt, det_w, angles, vol, sino)
status_fp_cpu = ccall(fp2d_cpu_sym, Cint,
    (Cint, Cint, Cint, Cint, Cfloat, Ptr{Cfloat}, Ptr{Cfloat}, Ptr{Cfloat}),
    2, 2, 2, 2, 1.0f0, angles, vol_cpu, sino_cpu)
@test status_fp_cpu == 1
println("CPU FP Sinogram:\n", sino_cpu)

recon_cpu = zeros(Float32, 2, 2)
# int astra_julia_bp2d_parallel_line_f32(vol_w, vol_h, angle_cnt, det_cnt, det_w, angles, sino, vol)
status_bp_cpu = ccall(bp2d_cpu_sym, Cint,
    (Cint, Cint, Cint, Cint, Cfloat, Ptr{Cfloat}, Ptr{Cfloat}, Ptr{Cfloat}),
    2, 2, 2, 2, 1.0f0, angles, sino_cpu, recon_cpu)
@test status_bp_cpu == 1
println("CPU BP Reconstruction:\n", recon_cpu)

# 3. 2D CUDA Parallel Forward & Backprojection
println("\n--- 3. 2D CUDA Parallel FP / BP ---")
fp2d_cuda_sym = Libdl.dlsym(lib, :astra_julia_cuda_fp2d_parallel_line_f32)
bp2d_cuda_sym = Libdl.dlsym(lib, :astra_julia_cuda_bp2d_parallel_f32)

vol_cuda = Float32[1.0 2.0; 3.0 4.0]
sino_cuda = zeros(Float32, 2, 2)
# int astra_julia_cuda_fp2d_parallel_line_f32(vol_w, vol_h, angle_cnt, det_cnt, det_w, angles, vol, sino, det_ss, gpu_idx)
status_fp_cuda = ccall(fp2d_cuda_sym, Cint,
    (Cint, Cint, Cint, Cint, Cfloat, Ptr{Cfloat}, Ptr{Cfloat}, Ptr{Cfloat}, Cint, Cint),
    2, 2, 2, 2, 1.0f0, angles, vol_cuda, sino_cuda, 1, -1)
if status_fp_cuda != 1
    err_msg = unsafe_string(ccall(last_error_sym, Cstring, ()))
    println("CUDA FP Error: ", err_msg)
end
@test status_fp_cuda == 1
println("CUDA FP Sinogram:\n", sino_cuda)

recon_cuda = zeros(Float32, 2, 2)
# int astra_julia_cuda_bp2d_parallel_f32(vol_w, vol_h, angle_cnt, det_cnt, det_w, angles, sino, vol, det_ss, pix_ss, gpu_idx)
status_bp_cuda = ccall(bp2d_cuda_sym, Cint,
    (Cint, Cint, Cint, Cint, Cfloat, Ptr{Cfloat}, Ptr{Cfloat}, Ptr{Cfloat}, Cint, Cint, Cint),
    2, 2, 2, 2, 1.0f0, angles, sino_cuda, recon_cuda, 1, 1, -1)
if status_bp_cuda != 1
    err_msg = unsafe_string(ccall(last_error_sym, Cstring, ()))
    println("CUDA BP Error: ", err_msg)
end
@test status_bp_cuda == 1
println("CUDA BP Reconstruction:\n", recon_cuda)

# 4. Consistency comparison between CPU and CUDA results
println("\n--- 4. CPU vs CUDA Numerical Consistency ---")
println("Max difference between CPU and CUDA sinogram: ", maximum(abs.(sino_cpu .- sino_cuda)))
@test isapprox(sino_cpu, sino_cuda; rtol = 1e-3, atol = 1e-3)

Libdl.dlclose(lib)
println("\n✅ All C ABI tests passed successfully on library: ", libpath)
