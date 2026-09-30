# Shared mise workflows retired

The shared task-library experiment has been retired. No shared task code was copied
into this repository. Independent project tasks remain in `mise.toml` and its local includes.

Removed local tasks: `cf:deploy`, `cf:deploy:hub`, `cf:tail`, `ci`.

Removed workflows: `.github/workflows/mise.yml`, `.github/workflows/mise-upgrade.yml`.

Imported bootstrap, validation, release, and other shared commands are no longer
available. Dependent workflows were retired with their prerequisites, rather than
running with fewer checks. These changes do not replace CI or release automation.

Provision the executables required by retained tasks explicitly; there is no shared
global bootstrap. Nushell scripts require `nu` on PATH; Rust uses the existing Rust
toolchain configuration. Existing project tool pins are unchanged.
