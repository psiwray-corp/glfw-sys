#!/usr/bin/env bash
# Create the signed v<version> tag on the release branch.
#
# Usage:
#   scripts/release-tag.sh <version> [--push] [--dry-run]
#
# Requires a clean worktree, the release/<major.minor> branch, and Cargo.toml
# at <version>. Tag signing is the manual GPG step.
set -euo pipefail

usage() {
    cat <<'EOF'
Create the signed v<version> tag.

Usage:
  scripts/release-tag.sh <version> [--push] [--dry-run]

Requires a clean worktree, release/<major.minor>, and Cargo.toml at <version>.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=lib.sh
source "$repo_root/scripts/lib.sh"

version=""
push=false
dry_run=false

while (($# > 0)); do
    case "$1" in
        --push)
            push=true
            shift
            ;;
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

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "not inside a Git worktree."

release_branch="release/${version%.*}"
current_branch="$(git symbolic-ref --quiet --short HEAD || true)"
[[ "$current_branch" == "$release_branch" ]] ||
    die "expected branch $release_branch, currently on ${current_branch:-detached HEAD}."

[[ -f Cargo.toml ]] || die "Cargo.toml not found."
project_version="$(read_package_version Cargo.toml)"
[[ "$project_version" == "$version" ]] ||
    die "Cargo.toml version is ${project_version:-missing}, expected $version."

[[ -z "$(git status --porcelain)" ]] ||
    die "worktree is dirty; commit the release tree first."

tag="v$version"
if git show-ref --verify --quiet "refs/tags/$tag"; then
    die "tag $tag already exists."
fi

crate_name="$(read_package_name Cargo.toml)"
[[ -n "$crate_name" ]] || die "cannot read package name from Cargo.toml."

if [[ "$dry_run" == true ]]; then
    echo "git tag -s $tag -m \"$crate_name $version\""
else
    git tag -s "$tag" -m "$crate_name $version"
    echo "created signed tag: $tag"
fi

if [[ "$push" == true ]]; then
    if [[ "$dry_run" == true ]]; then
        echo "git push $release_remote $tag"
    else
        git push "$release_remote" "$tag"
    fi
fi
