# sources/verify_sources.jl
# Verify SHA256 checksums of bundled files and upstream archive manifest.

using SHA
using TOML
using Downloads

const ROOT_DIR = normpath(joinpath(@__DIR__, ".."))
const MANIFEST_PATH = joinpath(@__DIR__, "manifest.toml")

function calculate_sha256(filepath::String)
    isfile(filepath) || error("File not found: $filepath")
    return bytes2hex(open(sha256, filepath))
end

function verify_bundled_files(manifest::Dict{String, Any})
    println("--- Verifying bundled files ---")
    bundled = get(manifest, "bundled", Dict{String, Any}())
    files = get(bundled, "files", Dict{String, Any}())
    
    all_ok = true
    for (relpath, expected_hash) in files
        fullpath = joinpath(ROOT_DIR, relpath)
        if !isfile(fullpath)
            println("❌ Missing: $relpath")
            all_ok = false
            continue
        end
        actual_hash = calculate_sha256(fullpath)
        if actual_hash == expected_hash
            println("✅ OK: $relpath")
        else
            println("❌ Hash mismatch for $relpath")
            println("   Expected: $expected_hash")
            println("   Actual:   $actual_hash")
            all_ok = false
        end
    end
    return all_ok
end

function verify_upstream_archive(manifest::Dict{String, Any}; download_if_missing::Bool = false)
    println("--- Verifying upstream archive ---")
    upstream = get(manifest, "upstream", Dict{String, Any}())
    archive_url = upstream["archive_url"]
    expected_hash = upstream["archive_sha256"]
    
    target_cache = joinpath(@__DIR__, basename(archive_url))
    if !isfile(target_cache)
        if download_if_missing
            println("Downloading upstream archive: $archive_url ...")
            Downloads.download(archive_url, target_cache)
        else
            println("⚠️ Archive not cached locally ($target_cache). Skipping archive payload test (use download_if_missing=true to test).")
            return true
        end
    end

    actual_hash = calculate_sha256(target_cache)
    if actual_hash == expected_hash
        println("✅ Upstream archive hash verified: $expected_hash")
        return true
    else
        println("❌ Upstream archive hash mismatch!")
        println("   Expected: $expected_hash")
        println("   Actual:   $actual_hash")
        return false
    end
end

function main()
    isfile(MANIFEST_PATH) || error("Manifest not found: $MANIFEST_PATH")
    manifest = TOML.parsefile(MANIFEST_PATH)

    bundled_ok = verify_bundled_files(manifest)
    archive_ok = verify_upstream_archive(manifest; download_if_missing = false)

    if bundled_ok && archive_ok
        println("\n🎉 All source manifest checks passed!")
        return 0
    else
        println("\n❌ Source manifest verification failed.")
        return 1
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
