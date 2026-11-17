#!/usr/bin/env bash
# Prepare a release without manual version commits:
#   0.1.0-dev -> commit 0.1.0 + signed v0.1.0 -> commit 0.1.1-dev
#
# Usage:
#   scripts/release-prepare.sh <version> [--dry-run]
#
# Run on release/<major.minor> with a clean worktree, <version>-dev in
# Cargo.toml, and a CHANGELOG heading for <version>. Commits are signed; GPG
# passphrase entry is manual.
set -euo pipefail

usage() {
    cat <<'EOF'
Prepare a release commit and signed tag, then the next patch dev commit.

Usage:
  scripts/release-prepare.sh <version> [--dry-run]

Run on release/<major.minor> with a clean worktree, Cargo.toml at
<version>-dev, and a CHANGELOG heading for <version>.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=lib.sh
source "$repo_root/scripts/lib.sh"

version=""
dry_run=false

while (($# > 0)); do
    case "$1" in
        --dry-run)
            dry_run=true
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            die "unknown option: $1"
            ;;
        *)
            [[ -z "$version" ]] || die "version specified more than once."
            version="$1"
            shift
            ;;
    esac
done

[[ -n "$version" ]] || {
    usage >&2
    exit 2
}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    die "version must look like MAJOR.MINOR.PATCH, got: $version"

major="${version%%.*}"
minor="${version#*.}"
minor="${minor%%.*}"
patch="${version##*.}"
next_version="${major}.${minor}.$((patch + 1))-dev"
release_branch="release/${major}.${minor}"
tag="v$version"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "not inside a Git worktree."

current_branch="$(git symbolic-ref --quiet --short HEAD || true)"
[[ "$current_branch" == "$release_branch" ]] ||
    die "expected branch $release_branch, currently on ${current_branch:-detached HEAD}."

[[ -f Cargo.toml ]] || die "Cargo.toml not found."
current_version="$(read_package_version Cargo.toml)"
[[ "$current_version" == "${version}-dev" ]] ||
    die "Cargo.toml version is ${current_version:-missing}, expected ${version}-dev."

[[ -z "$(git status --porcelain)" ]] ||
    die "worktree is dirty; commit release changes before preparing."

grep -Eq "^## \\[$version\\]" CHANGELOG.md ||
    die "CHANGELOG.md has no '## [$version]' release heading."

if git show-ref --verify --quiet "refs/tags/$tag"; then
    die "tag $tag already exists."
fi

if [[ "$dry_run" == true ]]; then
    echo "set Cargo.toml version = $version"
    echo "cargo metadata --format-version 1"
    echo "git add Cargo.toml Cargo.lock"
    echo "git commit -S -m \"Release $version.\""
    echo "scripts/release-tag.sh $version"
    echo "set Cargo.toml version = $next_version"
    echo "cargo metadata --format-version 1"
    echo "git add Cargo.toml Cargo.lock"
    echo "git commit -S -m \"Next development version $next_version.\""
    echo "prepared $tag; next dev version $next_version"
    exit 0
fi

write_package_version Cargo.toml "$version"
refresh_lockfile
commit_version_change "Release $version."

"$repo_root/scripts/release-tag.sh" "$version"

write_package_version Cargo.toml "$next_version"
refresh_lockfile
commit_version_change "Next development version $next_version."

echo "prepared $tag"
echo "next dev version: $next_version"
echo "build from tag: git switch --detach $tag"
