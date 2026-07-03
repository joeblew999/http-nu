#!/usr/bin/env nu

# Set up cross-compilation environment for aarch64-apple-darwin
$env.CC_aarch64_apple_darwin = "aarch64-apple-darwin22.4-clang"
$env.CXX_aarch64_apple_darwin = "aarch64-apple-darwin22.4-clang++"
$env.AR_aarch64_apple_darwin = "aarch64-apple-darwin22.4-ar"
$env.CFLAGS_aarch64_apple_darwin = "-fuse-ld=/usr/local/osxcross/target/bin/aarch64-apple-darwin22.4-ld"

# Parse command line arguments
def main [
    mode?: string  # pass --release for release mode
] {
    # BUILD_MODE holds the optional --release flag; BUILD_TYPE is the target subdir.
    let build_mode = if $mode == "--release" { ["--release"] } else { [] }
    let build_type = if $mode == "--release" {
        print "Building for aarch64-apple-darwin (release mode)..."
        "release"
    } else {
        print "Building for aarch64-apple-darwin (debug mode)..."
        "debug"
    }

    # First attempt - this will likely fail due to libproc issue.
    # Capture combined stdout+stderr, echo it to the terminal, and tee to build.log.
    let build = (^cargo build --target aarch64-apple-darwin ...$build_mode --color always | complete)
    let build_out = $"($build.stdout)($build.stderr)"
    print --no-newline $build_out
    $build_out | save -f build.log

    # Check if libproc error occurred
    if (open build.log | find --regex "osx_libproc_bindings.rs.*No such file" | is-not-empty) {
        print "Detected libproc issue, applying fix..."

        # Find the libproc source file
        let source_dir = (^find ...(glob "/root/.cargo/registry/src/index.crates.io-*") -name "libproc-*" -type d | lines | first)
        let source_file = ($source_dir | path join "docs_rs/osx_libproc_bindings.rs")

        # Find the destination directory
        let dest_base = (^find $"target/aarch64-apple-darwin/($build_type)/build/" -name "libproc-*" -type d | lines | first)
        let dest_dir = ($dest_base | path join "out")

        if ($source_file | path exists) and (($dest_dir | path type) == "dir") {
            print $"Copying ($source_file) to ($dest_dir)/"
            ^cp $source_file $"($dest_dir)/"

            print "Retrying build..."
            ^cargo build --target aarch64-apple-darwin ...$build_mode --color always
        } else {
            print "Error: Could not find source file or destination directory"
            print $"Source: ($source_file)"
            print $"Dest: ($dest_dir)"
            error make {msg: "Could not find source file or destination directory"}
        }
    }

    # Clean up log file
    rm -f build.log
}
