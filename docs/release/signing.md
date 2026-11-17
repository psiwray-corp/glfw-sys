# Release signing

**Only PsiWray, the key owner, may sign or publish a release.** Signing is
local-only; no CI job has the key or passphrase.

Rust releases do not ship per-artifact signatures. A release is authenticated
by:

1. signed commits (`git commit -S`);
2. a signed tag (`git tag -s`) pointing at the release commit;
3. the registry index checksum for the uploaded `.crate`.

The registry token authenticates uploads but is not a release signature.

## Key to trust

| Field | Value |
|---|---|
| Fingerprint | `DF3D36E23DD7159D456908CBB198A57BE07D7B77` |
| Long key ID | `B198A57BE07D7B77` |
| User ID | `PsiWray (Git) <development@psiwray.com>` |
| Algorithm | RSA 4096, signing-capable primary key |
| Created | 2023-07-29 |
| Expires | **2027-06-13** |

The key is the Git identity key, configured locally:

```bash
git config user.signingkey DF3D36E23DD7159D456908CBB198A57BE07D7B77
git config commit.gpgsign true
git config tag.gpgsign true
```

The secret key stays on the maintainer's device. It is not stored in GitHub,
Forgejo, or any CI system.

## Signing locally

The release scripts call `git commit -S` and `git tag -s`. GnuPG prompts for the
passphrase; enter it in pinentry. Do not put the passphrase in a shell command,
environment file, or CI secret.

A release commit and tag can be created manually if needed:

```bash
git commit -S -m "Release 0.1.0."
git tag -s v0.1.0 -m "glfw-sys 0.1.0"
```

## Verify with the public key only

Export the public key once:

```bash
gpg --armor --export DF3D36E23DD7159D456908CBB198A57BE07D7B77 \
  > /secure/path/release-key.asc
```

Then verify in a temporary, public-key-only keyring:

```bash
tmp="$(mktemp -d)"
GNUPGHOME="$tmp" gpg --batch --import /secure/path/release-key.asc
GNUPGHOME="$tmp" git verify-tag v0.1.0
rm -rf "$tmp"
```

`scripts/verify-release.sh <version>` verifies the tag signature, requires
`HEAD` to be the tagged commit, checks the manifest version, packages with
`cargo package --locked`, and prints the `.crate` SHA-256.

## Release authority and CI

- Releases are performed locally by the key owner; no other person or
  automation may sign or publish a release.
- There is deliberately no tag-triggered release workflow. CI, if present,
  builds and tests unsigned development versions and receives no signing key,
  passphrase, or registry token.
- Do not add `SIGNING_KEY`, `SIGNING_PASSWORD`, or `CARGO_REGISTRIES_*_TOKEN`
  secrets to either forge for release use.

## Rotation and revocation

- Rotate before **2027-06-13**. An expired key fails verification even when old
  signatures remain cryptographically valid.
- Keep the revocation certificate offline. If the key is compromised, publish
  the revocation, generate a new key, update `git config user.signingkey`, and
  update this document.
- Past releases stay signed by their original key; never re-sign or re-upload a
  published registry version.

## Related

[Release runbook](runbook.md) · [Publishing](publishing.md) ·
[Rollback](rollback.md)
