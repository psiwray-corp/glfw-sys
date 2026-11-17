# Publishing to Forgejo

Releases are published to the self-hosted Forgejo Cargo registry at
`https://forgejo.psiwray.com/`, owner `psiwray-corp`. The instance is reachable
over the VPN only.

Publication is local-only. The registry token is loaded into the maintainer's
shell and never stored in the repository or in CI. Git and tag signing are
covered in [signing.md](signing.md); the branch and tag sequence is in
[runbook.md](runbook.md).

## Registry configuration

`.cargo/config.toml` in this repository defines the registry and an explicit
credential provider:

```toml
[registries.forgejo]
index = "sparse+https://forgejo.psiwray.com/api/packages/psiwray-corp/cargo/"

[registry]
global-credential-providers = ["cargo:token"]
```

Without `global-credential-providers`, Cargo refuses to use an authenticated
alternative registry.

## Prerequisites

- The organization's `_cargo-index` repository exists. Forgejo creates and
  maintains it from the package settings page; do not edit it by hand.
- A Forgejo token with `write:packages` exists.
- The release tree is clean, checked out at the signed `v<version>` tag, and
  `Cargo.toml` carries `<version>` without a pre-release suffix.
- `CHANGELOG.md` has the `## [<version>]` heading.
- The system GLFW library (>= 3.5.1) is needed for the test gate; packaging
  itself does not link it.

Do not put the token in `.cargo/config.toml`, `Cargo.toml`, or a workflow.

## Token

Forgejo expects `Authorization: Bearer <token>`, so the stored value includes
the scheme:

```bash
read -rsp 'Forgejo token: ' FORGEJO_TOKEN; echo
export CARGO_REGISTRIES_FORGEJO_TOKEN="Bearer $FORGEJO_TOKEN"
```

Alternatively, store it once for the current user:

```bash
cargo login --registry forgejo "Bearer <token>"
```

The environment variable takes precedence and keeps the token out of the
credentials file; prefer it for a release session.

## Dry run

The index is private, so even a dry run needs the token:

```bash
cargo publish --dry-run --registry forgejo
```

This packages the crate, builds it from the archive, and stops before upload.

## Publish

```bash
cargo publish --registry forgejo
```

`publish = ["forgejo"]` in `Cargo.toml` prevents accidental publication to
crates.io. `cargo publish` refuses a dirty worktree by default; release from the
tagged commit.

Forgejo stores the `.crate` and writes the version metadata into
`_cargo-index`. The registry endpoint serves the sparse index, the crate
archive, and checksums.

## Verify

Check the package page in Forgejo and resolve the version from a clean consumer
project on the VPN:

```bash
tmp="$(mktemp -d)"
cargo new --lib "$tmp/consumer"
cd "$tmp/consumer"
mkdir -p .cargo
cat >.cargo/config.toml <<'EOF'
[registries.forgejo]
index = "sparse+https://forgejo.psiwray.com/api/packages/psiwray-corp/cargo/"

[registry]
global-credential-providers = ["cargo:token"]
EOF
cargo add glfw-sys --registry forgejo
cargo check
```

A failed resolution is not fixed by re-uploading the same version. Publish the
next patch version.

## Version policy

Forgejo can delete a package version, but this project treats published
versions as immutable: never delete and re-upload a version that consumers may
have resolved. Fix a bad release with `0.1.1`, `0.2.0`, or the next appropriate
version. Tags follow the same rule; see [rollback.md](rollback.md).

## Validation-error catalogue

| Error | Cause | Fix |
|---|---|---|
| `401`/`403` | Missing token, wrong scope, or missing `Bearer ` prefix | Recreate the token with `write:packages`; export `CARGO_REGISTRIES_FORGEJO_TOKEN="Bearer ..."` |
| `no token found for forgejo` | Token not visible to this shell | Export the variable or run `cargo login --registry forgejo` |
| `authenticated registries require a credential-provider` | `.cargo/config.toml` lacks the provider | Add `[registry] global-credential-providers = ["cargo:token"]` |
| `failed to update registry` | VPN down, wrong host, or missing `_cargo-index` | Check the VPN and the index repository in package settings |
| Duplicate version | Version already published | Publish the next patch/minor; never reuse it |
| `missing description` / `license` | Manifest metadata incomplete | Restore the fields in `Cargo.toml` |
| Dirty worktree | Release changes are uncommitted | Commit, or verify from the tagged checkout |
| System library missing | Tests cannot link GLFW | Install `libglfw3`/`glfw`; packaging alone does not need it |
| `version ... does not match tag` | Manifest and tag disagree | Fix the release commit and re-tag before publishing |

## Related

[Release runbook](runbook.md) · [Signing](signing.md) ·
[Rollback](rollback.md)
