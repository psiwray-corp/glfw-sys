# Release rollback

Registry versions are treated as immutable even though Forgejo can delete a
package version. Recovery depends on whether the version was published.

## Before the version is published

Use this when packaging, verification, or upload failed.

1. Fix the source on the release branch.
2. Delete the local tag if it was never pushed:

   ```bash
   git tag -d "v$VERSION"
   ```

3. Re-run the release preparation and verification.
4. Publish again.

If the bad tag or release commit was already pushed, do not force-rewrite
published history. Delete the remote tag only if the version was never
published, then create a corrected release commit and tag.

## After the version is published

Never delete, overwrite, or re-upload it. Publish the next version:

```bash
# For a hotfix, fix on master first.
git switch master
# Apply and test the fix.
git commit -S -m 'Fix <issue>'
export FIX_COMMIT="$(git rev-parse HEAD)"

git switch release/0.1
git cherry-pick -S "$FIX_COMMIT"
# Add the changelog heading and run the normal patch release procedure.
```

Patch releases use `0.1.1`, `0.1.2`, and so on. A breaking change requires a
new minor or major line, depending on the compatibility policy.

## Rollback table

| State | Action |
|---|---|
| Local signed build failed | Fix, delete local tag if present, rebuild |
| Verification failed | Fix, delete the unpushed tag, repeat |
| Upload failed | Fix, retry the same version only if it was never stored |
| Published on Forgejo | Never re-upload; publish the next patch/minor |
| Bad tag, not pushed, not published | Delete local tag; recreate from corrected commit |
| Bad tag, pushed, not published | Delete the remote tag with explicit approval; recreate |
| Bad tag, published | Keep the tag; publish a new version |
| Release branch merged into master by mistake | Revert the merge; keep development on master |

## Related

[Release runbook](runbook.md) · [Publishing](publishing.md) ·
[Signing](signing.md)
