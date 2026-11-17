# Release and hotfix runbook

This project uses a release branch per major/minor line. `master` always holds
the newest development version (`X.Y.Z-dev`). A release branch holds the
current development version for its patch line. A published version exists in
exactly one commit, and that commit is tagged.

Signing and publishing are local-only. The GPG key, passphrase, and Forgejo
token never enter CI. Upload mechanics are in [publishing.md](publishing.md);
key policy is in [signing.md](signing.md).

## Branch and version model

| Ref | Example | Meaning |
|---|---|---|
| `master` | `0.2.0-dev` | Newest development version |
| `release/0.1` | `0.1.1-dev` | Current development version of the 0.1 line |
| Tag `v0.1.0` | — | The one commit containing `0.1.0` |
| Tag `v0.1.1` | — | A hotfix release |

`Cargo.toml`'s `[package] version` is the version source of truth. The tag must
match it: `v${version}`. Never publish a `-dev` version.

```text
master:       0.1.0-dev
release/0.1:  0.1.0-dev
              |
              +-- commit 0.1.0 + tag v0.1.0
              |
release/0.1:  0.1.1-dev
master:       0.2.0-dev
```

Only the tagged commit contains the release version. The next commit restores
a development version. The next minor version is `0.2.0-dev`, not `1.0.0-dev`;
`1.0.0` is reserved for a deliberate breaking release.

Release branches are never merged back into `master`. Hotfixes land on `master`
first and are cherry-picked to the release branch.

## Before starting

- Rust 1.85+ and the toolchain used for the release gates.
- A clean `master` at `<version>-dev` and a committed `## [<version>]` changelog
  heading.
- A working GnuPG keyring; `git config user.signingkey` points at the release
  key. See [signing.md](signing.md).
- The system GLFW library (>= 3.5.1) for the test gate.
- A Forgejo token with `write:packages`, loaded into the current shell only.

```bash
export PUBLIC_KEY_FILE=/secure/path/release-key.asc
export VERSION=0.1.0
export MAJOR="${VERSION%%.*}"
export MINOR="${VERSION#*.}"
export MINOR="${MINOR%%.*}"
export RELEASE_BRANCH="release/${MAJOR}.${MINOR}"
export NEXT_MINOR="${MAJOR}.$((MINOR + 1)).0-dev"
export TAG="v$VERSION"
export DATE="$(date -u +%F)"
```

For `0.1.0`, these expand to `release/0.1`, `0.2.0-dev`, `v0.1.0`, and today's
UTC date. `release-prepare.sh` derives the next patch development version
(`0.1.1-dev`) itself.

## Quality gates

Run from the tag before publishing:

```bash
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test
scripts/verify-release.sh "$VERSION"
```

`verify-release.sh` checks the signed tag, requires `HEAD` to be the tagged
commit, validates the manifest version, runs `cargo package --locked`, and
prints the SHA-256 of the `.crate`. The test gate above needs the system GLFW
library.

## Git helper scripts

```bash
scripts/release.sh "$VERSION"               # all branch/commit/tag/master work
scripts/release.sh "$VERSION" --dry-run
scripts/release.sh "$VERSION" --master-next # master bump for an already-cut release
```

It creates `release/<major.minor>`, makes the release commit, creates the
signed tag, makes the next-patch development commit, moves `master` to the next
minor development version, and checks out the release tag for building.

Lower-level helpers:

```bash
scripts/release-branch.sh "$VERSION"             # create or switch release/<major.minor>
scripts/release-branch.sh "$VERSION" --push      # also push the branch
scripts/release-branch.sh "$VERSION" --from HEAD # non-default base for a new branch
scripts/release-prepare.sh "$VERSION"            # release commit + signed tag + next dev commit
scripts/release-tag.sh "$VERSION"                # tag only; used by release-prepare.sh
scripts/release-tag.sh "$VERSION" --push         # also push the tag
```

All accept `--dry-run`. `release-branch.sh` may be used with uncommitted
release-candidate changes; `release-prepare.sh`, `release-tag.sh`, and
`release.sh` require a clean worktree. Signed commits use `git commit -S`; the
GPG passphrase is entered manually. Push helpers target the `forgejo` remote;
set `RELEASE_REMOTE=<name>` to use another.

## Normal release

### 1. Commit the release changelog

On `master`, move the `[Unreleased]` entries under a heading for this release,
leave a new empty `## [Unreleased]` section, and commit:

```bash
git switch master
git pull --ff-only
# Edit CHANGELOG.md.
git add CHANGELOG.md
git commit -S -m "Release notes for $VERSION"
```

The one-shot release script requires this committed changelog heading.

### 2. Run the one-shot preparation

```bash
scripts/release.sh "$VERSION"
```

The script performs, in order:

1. create `release/<major.minor>` from `master`;
2. `0.1.0-dev` -> signed commit `Release 0.1.0`;
3. signed tag `v0.1.0`;
4. `0.1.0` -> signed commit `Next development version 0.1.1-dev.`;
5. `master` -> signed commit `Next development version 0.2.0-dev.`;
6. check out `v0.1.0`.

The release branch is left at `0.1.1-dev`; `master` is at `0.2.0-dev`; the tag
is the only commit containing `0.1.0`. Preview with `--dry-run`.

### 3. Build and verify from the tag

The one-shot script already checked out the tag:

```bash
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test
scripts/verify-release.sh "$VERSION"
```

The verification script must print `verified signed tag` and a SHA-256. If a
gate fails, delete the local tag and repeat.

### 4. Publish to Forgejo

Still on the tagged commit, load the registry token into the current shell
only, then publish:

```bash
read -rsp 'Forgejo token: ' FORGEJO_TOKEN; echo
export CARGO_REGISTRIES_FORGEJO_TOKEN="Bearer $FORGEJO_TOKEN"

cargo publish --registry forgejo
```

`cargo publish` re-runs packaging and uploads. The index and crate store are
private; see [publishing.md](publishing.md) for token setup and the error
catalogue.

### 5. Verify and push release refs

From a clean consumer project, resolve the new version (see
[publishing.md](publishing.md)), then push the refs:

```bash
git switch "$RELEASE_BRANCH"
git push forgejo "$RELEASE_BRANCH" "$TAG"

git switch master
git push forgejo master
```

Add another remote if the repository is mirrored; the release itself is cut on
Forgejo. The release branch is not merged back. After `0.1.0`, `master` is
`0.2.0-dev` and `release/0.1` is `0.1.1-dev`.

## Hotfix

A hotfix bumps only the third version element. The fix lands on `master` first
and is cherry-picked to the release branch; release branches are never merged
back.

```bash
export VERSION=0.1.1
export RELEASE_BRANCH=release/0.1
export TAG="v$VERSION"
export DATE="$(date -u +%F)"

git switch master
git pull --ff-only
```

### 1. Commit the fix on master

```bash
# Make and test the fix.
git add <fixed-files>
git commit -S -m "Fix <issue>"
export FIX_COMMIT="$(git rev-parse HEAD)"
```

### 2. Cherry-pick the fix to the release branch

```bash
git switch "$RELEASE_BRANCH"
git pull --ff-only
git cherry-pick -S "$FIX_COMMIT"
```

Add the hotfix entry under a new `## [$VERSION] - $DATE` heading and commit it:

```bash
git add CHANGELOG.md
git commit -S -m "Add $VERSION changelog"
```

### 3. Prepare and verify the patch release

```bash
scripts/release-prepare.sh "$VERSION"
git switch --detach "$TAG"

cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test
scripts/verify-release.sh "$VERSION"
```

Publish exactly as in the normal release. Then return to the release branch,
which preparation left at the next patch development version, and push:

```bash
git switch "$RELEASE_BRANCH"
git push forgejo "$RELEASE_BRANCH" "$TAG"
```

`master` already contains the fix; no merge or backport is needed.

## Failure and recovery rules

- Before Forgejo accepts the upload: delete the local tag if it was not pushed,
  fix the release commit, and repeat.
- After the version is published: never re-upload or re-tag it. Publish the next
  patch (`0.1.1`) or minor (`0.2.0`) version instead.
- A tag may be deleted locally or on the forge only if the version was never
  published.
- Never put the GPG passphrase or registry token in the repository or in a
  workflow.

See [rollback.md](rollback.md) for recovery details.
