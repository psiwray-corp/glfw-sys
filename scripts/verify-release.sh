#!/usr/bin/env bash
# Verify a tagged Cargo release:
#   - the tag is signed;
#   - HEAD is exactly the tagged commit;
#   - Cargo.toml carries the release version;
#   - the packaged crate builds and its SHA-256 is printed.
#
# Usage:
#   scripts/verify-release.sh <version>
#
# `cargo package` runs the crate's build script; a crate that generates
# bindings with a Python tool must expose its interpreter via the appropriate
# environment variable (for example GLAD_PYTHON).
set -euo pipefail

usage() {
    cat <<'EOF'
Verify a tagged Cargo release.

Usage:
  scripts/verify-release.sh <version>

Checks the signed tag, HEAD, Cargo.toml version, and `cargo package`; prints
the SHA-256 of the packaged .crate.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=lib.sh
source "$repo_root/scripts/lib.sh"

version="${1:-}"
[[ -n "$version" ]] || {
    usage >&2
    exit 2
}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    die "version must look like MAJOR.MINOR.PATCH, got: $version"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "not inside a Git worktree."

tag="v$version"
git rev-parse --verify "refs/tags/$tag^{commit}" >/dev/null 2>&1 ||
    die "tag $tag does not exist."
[[ -z "$(git status --porcelain)" ]] ||
    die "worktree is dirty; verify from a clean checkout."

git verify-tag "$tag"

tag_commit="$(git rev-parse "$tag^{commit}")"
head_commit="$(git rev-parse HEAD)"
[[ "$head_commit" == "$tag_commit" ]] ||
    die "HEAD ($head_commit) is not the tagged commit ($tag_commit); run: git switch --detach $tag"

current_version="$(read_package_version Cargo.toml)"
[[ "$current_version" == "$version" ]] ||
    die "Cargo.toml version is ${current_version:-missing}, expected $version."

crate_name="$(read_package_name Cargo.toml)"
[[ -n "$crate_name" ]] || die "cannot read package name from Cargo.toml."

cargo package --locked

crate_file="target/package/${crate_name}-${version}.crate"
[[ -f "$crate_file" ]] || die "packaged crate not found: $crate_file."

sha256="$(sha256sum "$crate_file" | awk '{ print $1 }')"
echo "verified signed tag: $tag"
echo "crate: $crate_file"
echo "sha256: $sha256"
