using Test
using Libdl

const DEFAULT_LIB = "/home/jov/git/prj/AstraToolbox.jl/deps/usr/lib/libastra.so"
const libpath = get(ENV, "ASTRA_JULIA_LIB", DEFAULT_LIB)

@testset "Builder4AstraToolbox Test Suite" begin

    @testset "ABI and Symbol Inspection" begin
        @test isfile(libpath)
        script_path = joinpath(@__DIR__, "..", "scripts", "inspect_abi.sh")
        @test isfile(script_path)
        cmd = `bash $script_path $libpath`
        @test success(cmd)
    end

    @testset "Direct C ABI Product Test" begin
        test_script = joinpath(@__DIR__, "..", "scripts", "test_products.jl")
        @test isfile(test_script)
        cmd = `julia --startup-file=no --project=$(joinpath(@__DIR__, "..")) $test_script $libpath`
        @test success(cmd)
    end

    @testset "C ABI 3D Algorithms Check" begin
        lib = Libdl.dlopen(libpath)
        @test lib != C_NULL

        # Check export of 3D symbols
        @test Libdl.dlsym_e(lib, :astra_julia_cuda_fp3d_parallel_f32) != C_NULL
        @test Libdl.dlsym_e(lib, :astra_julia_cuda_bp3d_parallel_f32) != C_NULL
        @test Libdl.dlsym_e(lib, :astra_julia_cuda_fp3d_cone_f32) != C_NULL
        @test Libdl.dlsym_e(lib, :astra_julia_cuda_bp3d_cone_f32) != C_NULL
        @test Libdl.dlsym_e(lib, :astra_julia_cuda_fdk3d_cone_f32) != C_NULL
        @test Libdl.dlsym_e(lib, :astra_julia_cuda_sirt3d_cone_f32) != C_NULL
        @test Libdl.dlsym_e(lib, :astra_julia_cuda_cgls3d_cone_f32) != C_NULL

        Libdl.dlclose(lib)
    end

    @testset "Wrapper Files Consistency" begin
        wrapper_dir = normpath(joinpath(@__DIR__, "..", "wrapper"))
        astra_wrapper = "/home/jov/git/prj/AstraToolbox.jl/deps/wrapper"
        if isdir(astra_wrapper)
            h1 = read(joinpath(wrapper_dir, "include", "astra", "julia_c_api.h"), String)
            h2 = read(joinpath(astra_wrapper, "include", "astra", "julia_c_api.h"), String)
            @test h1 == h2

            cpp1 = read(joinpath(wrapper_dir, "src", "julia_c_api.cpp"), String)
            cpp2 = read(joinpath(astra_wrapper, "src", "julia_c_api.cpp"), String)
            @test cpp1 == cpp2
        end
    end
end
