# Release Process Specification (`docs/release-process.md`)

This specification defines the formal release workflow for contributing the `libastra` build recipe to the community repository [JuliaPackaging/Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil) and integrating the resulting `AstraToolbox_jll` package into [AstraToolbox.jl](https://github.com/hashimoto-koh/AstraToolbox.jl).

---

## 1. Distribution and Registration Principles

- **Official JLLs via Yggdrasil are the Standard**:
  The Julia General registry maintainers do not accept new manually generated JLL packages. Therefore, this repository (`Builder4AstraToolbox`) serves as the staging and validation environment for recipes and patches, while official binary generation and registry publication occur via Pull Requests to Yggdrasil.
- **Repository Distinction**:
  - `hashimoto-koh/Builder4AstraToolbox`: Development, validation, and staging repository.
  - `JuliaPackaging/Yggdrasil/A/AstraToolbox/`: Official recipe directory in Yggdrasil.
  - `AstraToolbox_jll`: The Julia package automatically built, tagged, and registered by Yggdrasil's CI/CD.

---

## 2. Release and Registration Procedure

### Step 1: Local Verification in `Builder4AstraToolbox`
1. Ensure source revisions and SHA256 checksums in `sources/manifest.toml` are pinned and verified.
2. Confirm that `julia --startup-file=no --project=. sources/verify_sources.jl` passes.
3. Build the artifact tarball locally using `julia --startup-file=no --project=. build_tarballs.jl --verbose` inside the BinaryBuilder sandbox.
4. Extract the artifact to `products/extracted/` and verify dynamic dependencies and SONAME via `readelf -d`.
5. Run `test/runtests.jl` and `scripts/test_products.jl` against the built artifact `products/extracted/lib/libastra.so` and verify that all 114 C ABI symbols and numerical projection tests pass on target GPU hardware (`sm_86`).

### Step 2: Submitting a Pull Request to Yggdrasil
1. Fork `JuliaPackaging/Yggdrasil`.
2. Clone your fork and create a branch:
   ```bash
   git clone git@github.com:<your-username>/Yggdrasil.git
   cd Yggdrasil
   git checkout -b astra-toolbox-jll-initial
   ```
3. Copy the staged recipe directory:
   ```bash
   cp -r /path/to/Builder4AstraToolbox/yggdrasil/A/AstraToolbox A/
   ```
4. Test locally from Yggdrasil root (optional):
   ```bash
   julia --project=. A/AstraToolbox/build_tarballs.jl --verbose
   ```
5. Commit, push, and submit a PR to `JuliaPackaging/Yggdrasil:master`:
   ```bash
   git add A/AstraToolbox
   git commit -m "[AstraToolbox] Initial recipe for libastra (v2.4.0)"
   git push origin astra-toolbox-jll-initial
   ```
6. Monitor Yggdrasil CI/CD. Once merged, Yggdrasil's bot registers `AstraToolbox_jll` in Julia General.

### Step 3: Integration into `AstraToolbox.jl`
1. Create a dedicated branch in `AstraToolbox.jl` (e.g., `feature/astra-toolbox-jll`).
2. Apply the integration patch:
   ```bash
   git apply /path/to/Builder4AstraToolbox/patches/astra_toolbox_jl_integration.patch
   ```
3. Replace the placeholder UUID with the assigned `AstraToolbox_jll` UUID from Julia General.
4. Verify that `deps/build.jl` remains available as an optional developer fallback.
5. Run full test suite in `AstraToolbox.jl` with both CPU and CUDA backends:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```
6. Submit and merge the integration PR in `AstraToolbox.jl`.

---

## 3. Versioning Strategy

- **Upstream ASTRA Version**: Fixed at `2.4.0` (matching upstream commit `bd0323e9b4b243ee90bca41341927b05e6e816c8`).
- **JLL Build Number**: When updating only recipes or patches, increment the JLL build number (e.g., `v2.4.0+0`, `v2.4.0+1`).
- **Breaking ABI Changes**: If the C ABI (`include/astra/julia_c_api.h`) is altered, coordinate version bumps carefully following semantic versioning.

---

## 4. Version and ABI Correspondence Matrix

| `AstraToolbox_jll` Version | Upstream ASTRA Ref | Wrapper SHA256 | C ABI Symbols | CUDA Requirement | Target Platform | Compatible `AstraToolbox.jl` |
|---|---|---|---|---|---|---|
| `v2.4.0+0` | `bd0323e9b4b243ee90bca41341927b05e6e816c8` | `28618464...` (header)<br>`21c2d846...` (cpp) | 114 symbols (`astra_julia_*`) | CUDA 12 (`libcudart.so.12`, `libcufft.so`) | Linux x86_64 glibc | `v0.1.0`+ |

---

## 5. Upstream Synchronization Protocol

When upstream ASTRA tags a new release or updates `master`:
1. **Update Manifest**: Update `upstream.ref`, `upstream.archive_url`, and `upstream.archive_sha256` in `sources/manifest.toml`.
2. **Verify Integrity**: Run `julia --startup-file=no --project=. sources/verify_sources.jl`.
3. **Audit Wrapper & Patches**: Verify whether upstream modifies `build/linux/Makefile.in` or CUDA kernels (`cuda/2d/darthelper.cu`). Adjust patches in `bundled/patches/` if needed.
4. **Build and Validate**: Run `julia --startup-file=no --project=. build_tarballs.jl --verbose`.
5. **Inspect ABI**: Run `bash scripts/inspect_abi.sh` to confirm all 114 symbols remain exported without unintended changes.
6. **Execute Regression Suite**: Run `julia --startup-file=no --project=. test/runtests.jl` on target GPU hardware.
7. **Submit Yggdrasil PR**: Copy recipe to `yggdrasil/A/AstraToolbox/` and submit PR to Yggdrasil.

---

## 6. Rollback and Recovery Procedure

Preserving `deps/build.jl` in `AstraToolbox.jl` ensures a resilient fallback:
- **Instant Override via Environment Variable**:
  ```bash
  export ASTRA_JULIA_LIB="/path/to/custom/libastra.so"
  ```
- **Fallback to Local Compilation**:
  If JLL cannot be loaded or customized native flags are needed:
  ```julia
  using Pkg
  Pkg.build("AstraToolbox") # compiles into deps/usr/lib/libastra.so
  ```
- **Diagnostics**:
  Checking `AstraToolbox.LowLevel.library_path()` reports the currently resolved backend path.
