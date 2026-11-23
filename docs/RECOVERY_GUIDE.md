# PharmaAssist project recovery guide

This guide preserves the final implementation while allowing later instructor
changes to be reviewed and retained. It does not overwrite a working tree
automatically.

## Protected copies

- The final committed baseline is recorded on the local branch
  `backup/pharmaassist-2-final-2026-11-23`.
- A source-and-documentation project copy is stored beside the working
  repository as `CounterfeitPharmaceuticalDetection-final-backup-2026-11-23`.
- The backup copy includes tracked and non-ignored project files, including
  source, tests, docs, model/data artifacts in version control, and config
  templates. It excludes `.git`, virtual environments, caches, generated
  builds, and ignored secrets such as Android keystores and `key.properties`.
- Before relying on a backup, compare its `RECOVERY_MANIFEST.sha256` against
  files in the backup itself. The manifest describes the copied file set.

## Review professor changes first

From the project repository, inspect state and compare with the protected
baseline:

```powershell
git status --short
git diff --stat
git diff --name-status backup/pharmaassist-2-final-2026-11-23...main
git diff backup/pharmaassist-2-final-2026-11-23...main -- path/to/file
```

To compare a file to the external copy without replacing anything:

```powershell
Compare-Object (Get-Content path/to/file) (Get-Content ..\CounterfeitPharmaceuticalDetection-final-backup-2026-11-23\path\to\file)
```

For deleted files, use `git diff --name-status` and inspect the protected
baseline or external copy. Review each change and keep legitimate improvements.

## Restore one damaged file safely

First preserve the currently edited file outside the repository, then copy the
chosen baseline file into place and inspect the diff:

```powershell
Copy-Item path/to/file ..\file.before-recovery
Copy-Item ..\CounterfeitPharmaceuticalDetection-final-backup-2026-11-23\path\to\file path\to\file
git diff -- path/to/file
```

Alternatively restore a tracked file from the local backup branch into the
working tree (this does not commit it):

```powershell
git restore --source=backup/pharmaassist-2-final-2026-11-23 --worktree -- path/to/file
git diff -- path/to/file
```

Only restore a directory after reviewing its complete changed-file list. Use
an explicit set of paths rather than replacing the entire project directory.

## Recover a specific bad commit

If the undesired commit is already shared, create a revert commit so history
and later work remain visible:

```powershell
git log --oneline --decorate -12
git revert <bad-commit-sha>
```

Resolve conflicts manually, preserve legitimate later edits, then run the
project test suites. Avoid history rewrites on shared branches.

## Recover the full baseline

For a full recovery, make a new sibling working copy from the backup directory
or clone the repository and check out the local backup branch. Keep the
professor-modified directory intact until its changes have been reviewed and
selected changes reapplied. Do not use `git reset --hard` or `git clean` as a
default recovery action.

The Android keystore and `key.properties` are intentionally excluded from
project backups and Git. Keep the signing key in a separate secure backup;
without it, existing release APKs cannot be updated in place with a matching
signature. Deployment credentials must be restored from their secure secret
store, never from source control.
