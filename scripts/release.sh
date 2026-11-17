#!/usr/bin/env bash
# One-shot normal release preparation:
#   master dev -> release branch -> release commit/tag -> next patch dev
#   -> master next-minor dev -> checkout the release tag for building.
#
# Usage:
#   scripts/release.sh <version> [--master-next] [--dry-run]
#
# Run from master with a clean worktree. `--master-next` only performs the
# final master bump for an already-cut release. Signed commits and the signed
# tag prompt for the GPG passphrase; they are never bypassed.
set -euo pipefail

usage() {
    cat <<'EOF'
One-shot normal release preparation.

Usage:
  scripts/release.sh <version> [--master-next] [--dry-run]

Run from master with a clean worktree and a committed `## [version]` changelog
heading. --master-next only performs the final master bump for an already-cut
release. Signed commits and the signed tag prompt for the GPG passphrase.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=lib.sh
source "$repo_root/scripts/lib.sh"

version=""
dry_run=false
master_next=false

while (($# > 0)); do
    case "$1" in
        --master-next)
            master_next=true
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

major="${version%%.*}"
minor="${version#*.}"
minor="${minor%%.*}"
next_minor="${major}.$((minor + 1)).0-dev"
release_branch="release/${major}.${minor}"
tag="v$version"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "not inside a Git worktree."

[[ "$(git symbolic-ref --quiet --short HEAD || true)" == "master" ]] ||
    die "one-shot release must start on master."

[[ -f Cargo.toml ]] || die "Cargo.toml not found."
current_version="$(read_package_version Cargo.toml)"
[[ "$current_version" == "${version}-dev" ]] ||
    die "master version is ${current_version:-missing}, expected ${version}-dev."

[[ -z "$(git status --porcelain)" ]] ||
    die "worktree is dirty; commit release changes before releasing."

if [[ "$master_next" == true ]]; then
    if [[ "$dry_run" == true ]]; then
        echo "set Cargo.toml version = $next_minor"
        echo "cargo metadata --format-version 1"
        echo "git add Cargo.toml Cargo.lock"
        echo "git commit -S -m \"Next development version $next_minor.\""
    else
        write_package_version Cargo.toml "$next_minor"
        refresh_lockfile
        commit_version_change "Next development version $next_minor."
        echo "master: $next_minor"
    fi
    exit 0
fi

grep -Eq "^## \\[$version\\]" CHANGELOG.md ||
    die "CHANGELOG.md has no '## [$version]' release heading."

if git show-ref --verify --quiet "refs/heads/$release_branch"; then
    die "local branch $release_branch already exists."
fi
if git show-ref --verify --quiet "refs/remotes/$release_remote/$release_branch"; then
    die "remote branch $release_remote/$release_branch already exists."
fi
if git show-ref --verify --quiet "refs/tags/$tag"; then
    die "tag $tag already exists."
fi

if [[ "$dry_run" == true ]]; then
    echo "scripts/release-branch.sh $version"
    echo "scripts/release-prepare.sh $version"
    echo "git switch master"
    echo "set Cargo.toml version = $next_minor"
    echo "cargo metadata --format-version 1"
    echo "git add Cargo.toml Cargo.lock"
    echo "git commit -S -m \"Next development version $next_minor.\""
    echo "git switch --detach $tag"
    echo "release: $tag"
    echo "release branch: $release_branch"
    echo "master: $next_minor"
    exit 0
fi

"$repo_root/scripts/release-branch.sh" "$version"
"$repo_root/scripts/release-prepare.sh" "$version"

git switch master
write_package_version Cargo.toml "$next_minor"
refresh_lockfile
commit_version_change "Next development version $next_minor."

git switch --detach "$tag"

echo "release prepared: $tag"
echo "release branch: $release_branch"
echo "master: $next_minor"
echo "build from tag: git switch --detach $tag"
