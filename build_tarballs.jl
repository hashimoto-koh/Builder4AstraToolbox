using BinaryBuilder, Pkg
using Base.BinaryPlatforms

const YGGDRASIL_DIR = isdir(joinpath(@__DIR__, "..", "..", "platforms")) ? joinpath(@__DIR__, "..", "..") : @__DIR__
include(joinpath(YGGDRASIL_DIR, "platforms", "cuda.jl"))

name = "AstraToolbox"
version = v"2.4.0"

# Collection of sources generated before build
sources = [
    GitSource("https://github.com/astra-toolbox/astra-toolbox.git",
              "bd0323e9b4b243ee90bca41341927b05e6e816c8"),
    DirectorySource(joinpath(@__DIR__, "patches"); target = "patches"),
    DirectorySource(joinpath(@__DIR__, "wrapper"); target = "wrapper"),
]

# Bash recipe for building across all platforms
script = raw"""
cd ${WORKSPACE}/srcdir/astra-toolbox*

# Apply patches
for f in ${WORKSPACE}/srcdir/patches/*.patch; do
    echo "Applying patch ${f}..."
    atomic_patch -p1 ${f}
done

# Install Julia C ABI wrapper files
echo "Installing Julia C ABI wrapper..."
mkdir -p include/astra src
cp ${WORKSPACE}/srcdir/wrapper/include/astra/julia_c_api.h include/astra/
cp ${WORKSPACE}/srcdir/wrapper/src/julia_c_api.cpp src/

# Configure CUDA environment
export CUDA_HOME=${prefix}/cuda
export PATH=${CUDA_HOME}/bin:${PATH}

# Ensure lib64 symlink exists if SDK installed to lib
if [[ -d "${CUDA_HOME}/lib" && ! -d "${CUDA_HOME}/lib64" ]]; then
    ln -s lib "${CUDA_HOME}/lib64"
fi

# autogen and configure
cd build/linux
./autogen.sh

./configure --prefix=${prefix} \
            --host=${target} \
            --with-cuda=${CUDA_HOME} \
            --with-python=no \
            --with-matlab=no \
            --with-cuda-compute="all-major"

# Build libastra.la
make -j${nproc} libastra.la

# Install products
mkdir -p ${libdir}
cp -L .libs/libastra.so ${libdir}/libastra.so
cp -P .libs/libastra.so* ${libdir}/ || true

# Install license
cd ${WORKSPACE}/srcdir/astra-toolbox*
install_license COPYING

# Clean up CUDA SDK from output prefix so it does not get bundled into the artifact
rm -rf ${prefix}/cuda
"""

# Only CUDA-enabled platforms are supported (Linux x86_64, CUDA 12)
# CPU-only JLL or variant is not supported.
cuda_platforms = CUDA.supported_platforms(; min_version = v"12.0", max_version = v"12.9")
filter!(p -> arch(p) == "x86_64" && os(p) == "linux" && libc(p) == "glibc", cuda_platforms)
cuda_platforms = expand_cxxstring_abis(cuda_platforms)

products = [
    LibraryProduct("libastra", :libastra)
]

dependencies = [
    Dependency(PackageSpec(name = "CompilerSupportLibraries_jll")),
]

# Select and build platforms
const requested_triplets = let args = filter(a -> !startswith(a, "--"), ARGS)
    isempty(args) ? nothing : Set(String.(split(join(args, ","), ",")))
end
const requested_tags = requested_triplets === nothing ? nothing :
    Set(Base.BinaryPlatforms.tags(parse(Platform, t)) for t in requested_triplets)
wanted(p) = requested_tags === nothing || Base.BinaryPlatforms.tags(p) in requested_tags

non_platform_ARGS = filter(arg -> startswith(arg, "--"), ARGS)
non_reg_ARGS = filter(arg -> arg != "--register", non_platform_ARGS)

builds = []
for platform in cuda_platforms
    wanted(platform) || continue
    push!(builds, (;
        platform,
        sources,
        products,
        dependencies = [dependencies; CUDA.required_dependencies(platform)],
        dont_dlopen = true, # libcuda.so is not available inside the sandbox
    ))
end

if isempty(builds) && any(arg -> arg in ("--help", "-h"), ARGS)
    # If just asking for help, invoke build_tarballs with dummy platform
    build_tarballs(ARGS, name, version, sources, script, [Platform("x86_64", "linux")], products, dependencies)
    exit(0)
elseif isempty(builds)
    error("No platform matched the requested triplet(s): $(join(something(requested_triplets, []), ", "))")
end

for (i, build) in enumerate(builds)
    build_tarballs(i == lastindex(builds) ? non_platform_ARGS : non_reg_ARGS,
                   name, version, build.sources, script, [build.platform],
                   build.products, build.dependencies;
                   julia_compat = "1.10",
                   preferred_gcc_version = v"10",
                   lazy_artifacts = true,
                   augment_platform_block = CUDA.augment,
                   dont_dlopen = build.dont_dlopen)
end
