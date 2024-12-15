# fedora-createrepo-image

[![Build all](https://github.com/xlionjuan/fedora-createrepo-image/actions/workflows/build_all.yml/badge.svg)](https://github.com/xlionjuan/fedora-createrepo-image/actions/workflows/build_all.yml)

Build a Fedora based container image just for creating and building [RPM](https://github.com/xlionjuan/rustdesk-rpm-repo/tree/main/createrepo) and also [APT repo](https://github.com/xlionjuan/apt-repo-action).

By creating and using this container images, it can save ***time, resources and energy***, because it won't need to update package lists and install dependencies every times when it runs.

I mainly use it on all of my RustDesk repos. (Check my profile)

## Frequency

Build once a week. 

## Installed packages

Please refer to Dockerfile.

## Tagging
The latest will be `latest`, and a date (`yyyymmdd`) tag if you wanna specific environment or testing.

## Use this container in actions
Just add `container: ghcr.io/xlionjuan/fedora-createrepo-image:latest` after `runs-on: ubuntu-latest`, I recommend you to use `ubuntu-latest` to ensure the Docker Engine is the latest version.

```yml
jobs:
    build:
      runs-on: ubuntu-latest
      container: ghcr.io/xlionjuan/fedora-createrepo-image:latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v4
      .....
      .....
```

Note: minimal image is [dropped](https://github.com/xlionjuan/fedora-createrepo-image/issues/3).

## Verify the container

The container will be signed with [cosign](https://github.com/sigstore/cosign) and [GitHub Attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds), you can verify the container before you using it in the workflow.

This is an example workflow for verifying the container before using the container.

```yaml
jobs:
    verify:
      name: Verify container
      runs-on: ubuntu-latest # Keep latest, this work is too basic that don't need to pin to specific OS version.
      steps:
        # If you want to use cosign to verify the container, you should install cosign first.

        - name: Install Cosign
          uses: sigstore/cosign-installer@v3.7.0

        - name: Verify with cosign
          run: |
            cosign verify --rekor-url=https://rekor.sigstore.dev \
            --certificate-identity-regexp "https://github.com/xlionjuan/.*" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            ghcr.io/xlionjuan/fedora-createrepo-image:latest

        # Unfortunately, gh can't do anything without login, even just `gh attestation verify` command
        # so it needs to login, but NO any permissions is required.

        - name: Verify with gh
          env:
            GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          run: gh attestation verify --owner xlionjuan oci://ghcr.io/xlionjuan/fedora-createrepo-image:latest

    build:
      runs-on: ubuntu-latest # Everything will happened in the container so also not need to pin to specific OS version.
      needs: verify # So this will only runs if "verify" is passed.
      container: ghcr.io/xlionjuan/fedora-createrepo-image:latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v4

        - name: Do something
          run: rpm -qa
```
