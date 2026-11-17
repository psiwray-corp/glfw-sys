#!/usr/bin/env bash
# Create or switch to the release/<major.minor> branch for a version.
#
# Usage:
#   scripts/release-branch.sh <version> [--from <ref>] [--push] [--dry-run]
#
# <version> is a release version such as 0.1.0; release/0.1 is selected.
# A new branch must start from <version>-dev. The working tree may be dirty:
# uncommitted release-candidate changes carry across a normal branch switch,
# and Git refuses the switch on conflicts.
set -euo pipefail

usage() {
    cat <<'EOF'
Create or switch to the release/<major.minor> branch.

Usage:
  scripts/release-branch.sh <version> [--from <ref>] [--push] [--dry-run]

A new branch must start from <version>-dev. --push also pushes the branch.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=lib.sh
source "$repo_root/scripts/lib.sh"

version=""
from="master"
push=false
dry_run=false

while (($# > 0)); do
    case "$1" in
        --from)
            (($# >= 2)) || die "--from requires a ref."
            from="$2"
            shift 2
            ;;
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

release_branch="release/${version%.*}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "not inside a Git worktree."

if git show-ref --verify --quiet "refs/heads/$release_branch"; then
    if [[ "$from" != "master" ]]; then
        die "local branch $release_branch already exists; --from is only for creating it."
    fi
    if [[ "$(git symbolic-ref --quiet --short HEAD)" == "$release_branch" ]]; then
        echo "already on $release_branch"
    elif [[ "$dry_run" == true ]]; then
        echo "git switch $release_branch"
    else
        git switch "$release_branch"
    fi
elif git show-ref --verify --quiet "refs/remotes/$release_remote/$release_branch"; then
    if [[ "$from" != "master" ]]; then
        die "remote branch $release_remote/$release_branch already exists; --from is only for creating it."
    fi
    if [[ "$dry_run" == true ]]; then
        echo "git switch --track $release_remote/$release_branch"
    else
        git switch --track "$release_remote/$release_branch"
    fi
else
    git rev-parse --verify "$from^{commit}" >/dev/null 2>&1 ||
        die "base ref does not resolve to a commit: $from"
    [[ -f Cargo.toml ]] || die "Cargo.toml not found."
    current_version="$(read_package_version Cargo.toml)"
    [[ "$current_version" == "${version}-dev" ]] ||
        die "a new $release_branch branch must start from ${version}-dev; Cargo.toml is ${current_version:-missing}."
    if [[ "$dry_run" == true ]]; then
        echo "git switch -c $release_branch $from"
    else
        git switch -c "$release_branch" "$from"
    fi
fi

if [[ "$push" == true ]]; then
    if [[ "$dry_run" == true ]]; then
        echo "git push -u $release_remote $release_branch"
    else
        git push -u "$release_remote" "$release_branch"
    fi
fi

echo "release branch: $release_branch"
