# Scripts

## Overview

Files under `scripts/` are copied into `/usr/bin` by the container image. Package repository workflows use these commands as CI building blocks.

The scripts should stay small. They should wrap one clear responsibility, expose stable flags, and avoid hiding repository-specific decisions behind a generic abstraction.

## General Design

### Keep Scripts Focused

Each script should have one main job.

Good examples:

- `xlion-repo-utils-gh` handles GitHub release metadata and checksum verification.
- `xlion-repo-gpg-import` imports a GPG key and reports the fingerprint.
- `xlion-repo-repackage-deb` repackages DEB files with consistent fpm options.
- `xlion-repo-repackage-rpm` repackages RPM files with consistent fpm options.

Avoid scripts that do too much, such as one command that downloads assets, repackages packages, signs metadata, publishes repositories, and uploads artifacts. Those workflows are easier to reason about when they remain separate steps.

### Keep Product Rules Near the Caller

Not every repeated shell line needs a shared abstraction. For example, RustDesk release assets have product-specific naming rules around architecture, `sciter`, nightly builds, and SUSE RPMs. Simple workflow filtering with `grep` is often clearer than a generic selector command with many flags.

Use shared scripts for stable mechanics:

- GitHub release API access
- checksum verification
- GPG key import
- package reversion or repackaging when the behavior is identical
- RPM signing and metadata creation when those helpers exist

Keep caller-specific choices in the workflow:

- which upstream repository to use
- which release tag to use
- which package names or architectures to include
- how to lay out product-specific publish directories

### stdout and stderr

If a script is useful in command substitution, stdout should be machine-readable.

For example, `xlion-repo-gpg-import` prints only the fingerprint to stdout. Status messages go to stderr. This allows safe usage like:

```bash
fingerprint="$(xlion-repo-gpg-import --key-env GPG_PRIVATE_KEY)"
```

Scripts that generate human-readable reports can write normal logs to stdout if they are not expected to be used this way. Be deliberate and document the behavior.

### Secrets

Scripts must not print secrets. This includes:

- GPG private keys
- GitHub tokens
- Cloudflare R2 credentials
- full environment dumps

Accept secret material through environment variables or stdin. Prefer letting the caller choose the environment variable name with a flag such as `--key-env`.

### Temporary State

Temporary state should have an obvious owner.

For GPG, `GNUPGHOME` must remain available to later steps that run `gpg`, `aptly`, or `rpmsign`. `xlion-repo-gpg-import` may create `GNUPGHOME`, but it intentionally does not delete it. The workflow should clean it up in an `if: always()` step when signing is finished.

## Script Reference

### `xlion-repo-utils-gh`

`xlion-repo-utils-gh` has two modes.

Fetch mode:

```bash
xlion-repo-utils-gh --workfolder "$WORKFOLDER" --repo rustdesk/rustdesk
```

Fetch a specific tag:

```bash
xlion-repo-utils-gh --workfolder "$WORKFOLDER" --repo rustdesk/rustdesk --tag nightly
```

Verify downloaded files:

```bash
xlion-repo-utils-gh --verify --workfolder "$WORKFOLDER"
```

Fetch mode writes:

- `api.json`
- `dl_urls.txt`
- `sha256.txt` when release asset digests are available

Typical caller flow:

```bash
xlion-repo-utils-gh --workfolder "$WORKFOLDER" --repo pendulum-project/ntpd-rs
cd "$WORKFOLDER"
grep -E '\.deb$|\.rpm$' dl_urls.txt | wget2 --input-file=-
xlion-repo-utils-gh --verify --workfolder "$WORKFOLDER"
```

What this script owns:

- GitHub release API calls
- writing release URL and checksum files
- checksum verification

What this script does not own:

- deciding which packages a product repo wants
- downloading every possible asset automatically
- repository metadata generation
- package signing

Minimum tests:

```bash
bash -n scripts/xlion-repo-utils-gh
scripts/xlion-repo-utils-gh --help
```

If network access is acceptable, also test a small fetch-only scenario against a known public release.

### `xlion-repo-gpg-import`

`xlion-repo-gpg-import` imports a private key and prints the imported fingerprint.

Recommended GitHub Actions usage:

```bash
xlion-repo-gpg-import \
  --key-env GPG_PRIVATE_KEY \
  --create-gnupghome \
  --github-env \
  --name GPG_FINGERPRINT
```

This writes these variables for later workflow steps:

```bash
GNUPGHOME=/tmp/...
GPG_TTY=
GPG_FINGERPRINT=...
```

Use stdin for local testing or when the caller does not want to store the key in an environment variable:

```bash
xlion-repo-gpg-import --stdin --create-gnupghome < private-key.asc
```

Use RPM key import when later steps call `rpmsign` or verify RPM signatures:

```bash
xlion-repo-gpg-import \
  --key-env GPG_PRIVATE_KEY \
  --create-gnupghome \
  --github-env \
  --rpmkeys-import
```

What this script owns:

- reading private key material from stdin or a caller-selected environment variable
- creating `GNUPGHOME` when requested
- importing the private key with `gpg`
- parsing and reporting the fingerprint
- optionally importing the public key into rpm's key database

What this script does not own:

- publishing APT repositories
- signing RPM packages
- signing `repomd.xml`
- deleting `GNUPGHOME`
- choosing the secret name used by a workflow

Minimum tests:

```bash
bash -n scripts/xlion-repo-gpg-import
scripts/xlion-repo-gpg-import --help
```

Functional test with a throwaway key:

```bash
tmp_src="$(mktemp -d)"
tmp_env="$(mktemp)"
chmod 700 "$tmp_src"

GNUPGHOME="$tmp_src" \
  gpg --batch --passphrase '' \
  --quick-generate-key "XLion Repo Test <xlion-repo-test@example.invalid>" \
  default default 1d >/dev/null 2>&1

key_data="$(GNUPGHOME="$tmp_src" gpg --batch --armor --export-secret-keys "xlion-repo-test@example.invalid")"

fingerprint="$({
  GITHUB_ENV="$tmp_env" \
  GPG_PRIVATE_KEY="$key_data" \
  scripts/xlion-repo-gpg-import \
    --key-env GPG_PRIVATE_KEY \
    --create-gnupghome \
    --github-env
})"

test -n "$fingerprint"
grep -q '^GNUPGHOME=' "$tmp_env"
grep -qx 'GPG_TTY=' "$tmp_env"
grep -q '^GPG_FINGERPRINT=' "$tmp_env"

imported_home="$(grep '^GNUPGHOME=' "$tmp_env" | cut -d= -f2-)"
GNUPGHOME="$imported_home" gpg --batch --list-secret-keys "$fingerprint" >/dev/null

rm -rf "$tmp_src" "$imported_home" "$tmp_env"
```

### `xlion-repo-repackage-deb`

`xlion-repo-repackage-deb` repackages `.deb` files from a source directory into a target directory.

Latest-style repackaging without changing the package version:

```bash
xlion-repo-repackage-deb \
  --source-dir ori \
  --target-dir . \
  --deb-recommends xlion-repo-archive-keyring \
  --remove-source-dir
```

Nightly-style repackaging with a date suffix:

```bash
xlion-repo-repackage-deb \
  --source-dir ori \
  --target-dir . \
  --date-version \
  --deb-recommends xlion-repo-archive-keyring \
  --remove-source-dir
```

This turns an original version such as `1.2.3` into `1.2.3+YYYYMMDD`.

What this script owns:

- scanning one source directory for `.deb` files
- reading original package versions with `dpkg-deb`
- calling `fpm -t deb -s deb`
- applying `--deb-compression`
- optionally adding `--deb-recommends`
- optionally removing the source directory after success

What this script does not own:

- downloading upstream release assets
- deciding which architecture packages should exist
- creating APT repository metadata
- signing APT repositories

Minimum tests:

```bash
bash -n scripts/xlion-repo-repackage-deb
scripts/xlion-repo-repackage-deb --help
```

Functional testing should use a small throwaway `.deb` package. Confirm that the repackaged output exists, and when `--date-version` is used, confirm the output package `Version` contains `+YYYYMMDD`.

### `xlion-repo-repackage-rpm`

`xlion-repo-repackage-rpm` repackages `.rpm` files from a source directory into a target directory. By default, the target directory is the parent of the source directory. This matches common `wwwroot/channel/ori` usage.

Latest-style repackaging without changing the package version:

```bash
xlion-repo-repackage-rpm \
  --source-dir wwwroot/latest/ori \
  --remove-source-dir
```

Nightly-style repackaging with a date suffix:

```bash
xlion-repo-repackage-rpm \
  --source-dir wwwroot/nightly/ori \
  --date-version \
  --remove-source-dir
```

This turns an original version such as `1.2.3` into `1.2.3+YYYYMMDD`.

What this script owns:

- scanning one source directory for `.rpm` files
- reading original package versions with `rpm -qp`
- calling `fpm -t rpm -s rpm`
- applying `--rpm-compression`
- optionally removing the source directory after success

What this script does not own:

- splitting SUSE and non-SUSE packages
- creating RPM repository metadata
- importing GPG keys
- signing RPM packages
- signing `repomd.xml`

Minimum tests:

```bash
bash -n scripts/xlion-repo-repackage-rpm
scripts/xlion-repo-repackage-rpm --help
```

Functional testing should use a small throwaway `.rpm` package. Confirm that the repackaged output exists, and when `--date-version` is used, confirm the output package version contains `+YYYYMMDD`.

## Adding a New Script

Before adding a new script, check whether it is actually a stable shared mechanic. If the logic is mostly product-specific filtering or directory layout, keep it in the calling workflow.

When a new script is justified:

- Add it under `scripts/` with an executable bit.
- Include `--help` output.
- Validate dependencies and inputs.
- Keep stdout behavior documented.
- Add or update documentation in this file.
- Run `bash -n` and at least one practical functional test.

## Container Integration

The `Dockerfile` currently contains:

```Dockerfile
COPY scripts/* /usr/bin
```

That means every file under `scripts/` becomes available in the image PATH. Do not add non-executable notes, fixtures, or test data under `scripts/`; put documentation under `docs/` instead.
