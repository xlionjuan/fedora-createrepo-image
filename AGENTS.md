# Repository Guidance

## Scope

This repository builds the container image used by the Linux package repository workflows. The most important maintained interface is the set of executable scripts under `scripts/`; `Dockerfile` copies every file from `scripts/` into `/usr/bin`.

Treat scripts as public CI tools. Other repositories may call them directly from GitHub Actions, so changes should be small, explicit, and backward-compatible unless a caller migration is part of the same change.

## Script Design Rules

- Use Bash for small CLI orchestration around existing tools such as `gpg`, `gh`, `jq`, `curl`, `wget2`, `fpm`, `aptly`, `rpmkeys`, and `createrepo_c`.
- Start scripts with `#!/bin/bash` and `set -euo pipefail` unless there is a concrete reason not to.
- Keep stdout machine-readable when the script is commonly used in command substitution. Send logs, warnings, and errors to stderr.
- Do not print secrets, private keys, tokens, or full secret-derived command lines.
- Keep option names descriptive and stable. Prefer `--key-env GPG_PRIVATE_KEY` over hard-coding secret environment variable names.
- Validate required dependencies near the start and fail with a clear message.
- Validate required inputs before doing network, signing, or destructive file operations.
- Prefer explicit arguments over hidden repository-specific behavior.
- Do not make generic scripts understand every product-specific rule. Keep product-specific asset filtering in the calling workflow when plain shell is clearer.
- Do not delete state that later workflow steps need. For example, `xlion-repo-gpg-import` must not delete `GNUPGHOME` after importing a key.

## Current Scripts

### `xlion-repo-utils-gh`

Purpose: fetch GitHub release metadata, write release asset URLs to `dl_urls.txt`, write SHA256 data to `sha256.txt` when GitHub exposes asset digests, and verify downloaded files against that checksum file.

Design intent: this script owns GitHub release API interaction and checksum verification. It does not decide which assets a package repo should download. Callers can keep simple and readable filtering such as `grep '\.deb'`, `grep x86_64`, or `grep -v sciter` in their own workflow.

Expected outputs in fetch mode:

- `api.json`
- `dl_urls.txt`
- `sha256.txt` when digest data exists

Expected behavior in verify mode:

- Read `sha256.txt` from the workfolder.
- Verify only files that were actually downloaded into the workfolder.
- Fail if any downloaded file has a checksum mismatch.

### `xlion-repo-gpg-import`

Purpose: import a GPG private key into `GNUPGHOME`, report the imported fingerprint, and optionally export that fingerprint to GitHub Actions environment or output files.

Design intent: this script only prepares GPG key state. It must not publish repositories, sign packages, run `aptly`, run `rpmsign`, or clean up `GNUPGHOME`.

Common GitHub Actions usage:

```bash
xlion-repo-gpg-import \
  --key-env GPG_PRIVATE_KEY \
  --create-gnupghome \
  --github-env \
  --name GPG_FINGERPRINT
```

RPM workflows can also import the public key into rpm's key database:

```bash
xlion-repo-gpg-import \
  --key-env GPG_PRIVATE_KEY \
  --create-gnupghome \
  --github-env \
  --name GPG_FINGERPRINT \
  --rpmkeys-import
```

Expected output behavior:

- stdout prints only the fingerprint.
- logs and errors go to stderr.
- `--github-env` writes the fingerprint to `$GITHUB_ENV`.
- `--create-gnupghome --github-env` also writes `GNUPGHOME=...` and `GPG_TTY=` to `$GITHUB_ENV`.

### `xlion-repo-repackage-deb`

Purpose: repackage `.deb` files with `fpm`, optionally appending a date suffix to the original package version and adding Debian `Recommends` metadata.

Design intent: this script owns repeatable DEB repackaging mechanics only. It must not download release assets, create APT metadata, import signing keys, or publish repositories.

Common usage:

```bash
xlion-repo-repackage-deb \
  --source-dir ori \
  --target-dir . \
  --deb-recommends xlion-repo-archive-keyring \
  --remove-source-dir
```

Nightly/date-version usage:

```bash
xlion-repo-repackage-deb \
  --source-dir ori \
  --target-dir . \
  --date-version \
  --deb-recommends xlion-repo-archive-keyring \
  --remove-source-dir
```

### `xlion-repo-repackage-rpm`

Purpose: repackage `.rpm` files with `fpm`, optionally appending a date suffix to the original package version.

Design intent: this script owns repeatable RPM repackaging mechanics only. It must not split product-specific RPM layouts, create `createrepo_c` metadata, import signing keys, or sign packages.

Common usage:

```bash
xlion-repo-repackage-rpm --source-dir wwwroot/latest/ori --remove-source-dir
```

Nightly/date-version usage:

```bash
xlion-repo-repackage-rpm --source-dir wwwroot/nightly/ori --date-version --remove-source-dir
```

## Testing Requirements

Run at least syntax checks for every changed Bash script:

```bash
bash -n scripts/xlion-repo-utils-gh
bash -n scripts/xlion-repo-gpg-import
bash -n scripts/xlion-repo-repackage-deb
bash -n scripts/xlion-repo-repackage-rpm
```

For scripts with CLI help, verify help still renders:

```bash
scripts/xlion-repo-utils-gh --help
scripts/xlion-repo-gpg-import --help
scripts/xlion-repo-repackage-deb --help
scripts/xlion-repo-repackage-rpm --help
```

For `xlion-repo-gpg-import`, test with a temporary local GPG key instead of real secrets. The test should confirm that:

- a fingerprint is printed to stdout
- a secret key exists in the target `GNUPGHOME`
- `--create-gnupghome --github-env` writes `GNUPGHOME`, `GPG_TTY=`, and `GPG_FINGERPRINT`

Avoid tests that require real signing keys or real repository publishing.

## Documentation

When adding or changing a script, update `docs/scripts.md` with:

- the script's purpose
- what it owns and what it intentionally does not own
- common examples
- minimum test commands

Keep documentation plain and practical. The primary reader is someone editing CI scripts under time pressure.
