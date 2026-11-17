#!/usr/bin/env bash
# Shared helpers for the release scripts. Sourced, never executed directly.

set -euo pipefail

# Remote used by --push and remote-branch checks. Defaults to the Forgejo
# remote configured in this repository.
release_remote="${RELEASE_REMOTE:-forgejo}"

die() {
    echo "error: $*" >&2
    exit 1
}

# Reads the `[package] name` from a Cargo.toml.
read_package_name() {
    awk -F'"' '
        /^\[package\]/ { in_package = 1; next }
        in_package && /^name = "/ { print $2; exit }
    ' "$1"
}

# Reads the `[package] version` from a Cargo.toml.
read_package_version() {
    awk -F'"' '
        /^\[package\]/ { in_package = 1; next }
        in_package && /^version = "/ { print $2; exit }
    ' "$1"
}

# Replaces only the `[package] version` line.
write_package_version() {
    local file="$1" version="$2" tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    awk -v version="$version" '
        /^\[package\]/ { in_package = 1 }
        in_package && /^version = "/ {
            sub(/^version = "[^"]*"/, "version = \"" version "\"")
            in_package = 0
        }
        { print }
    ' "$file" >"$tmp"
    mv "$tmp" "$file"
}

# Keeps Cargo.lock in sync with the manifest after a version change.
refresh_lockfile() {
    cargo metadata --format-version 1 >/dev/null
}

# Stages the version change (and lockfile) and creates a signed commit.
commit_version_change() {
    local message="$1"
    git add Cargo.toml
    if [[ -f Cargo.lock ]]; then
        git add Cargo.lock
    fi
    git commit -S -m "$message"
}
