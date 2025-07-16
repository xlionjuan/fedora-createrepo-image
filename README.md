# fedora-createrepo-image

[![Build all](https://github.com/xlionjuan/fedora-createrepo-image/actions/workflows/build_all.yml/badge.svg)](https://github.com/xlionjuan/fedora-createrepo-image/actions/workflows/build_all.yml)

Build a Fedora based container image just for creating and building [RPM](https://github.com/xlionjuan/rustdesk-rpm-repo/tree/main/createrepo) and also [APT](https://github.com/xlionjuan/apt-repo-action) repo.

By creating and using this container images, it can save ***time, resources and energy***, because it won't need to update package lists and install dependencies every times when it runs.

I mainly use it on all of my RustDesk repos. (Check my profile)

## Frequency

~~Build once a week.~~ When new base images available.

## Installed packages

Most for the packages that for packaging `.deb` and `.rpm`, and the packages for creating its repos, and [fpm](https://github.com/jordansissel/fpm) for reversioning and repackaging packages, for more details, please refer to the Dockerfile.

## Tagging
The latest will be `latest`, and a date (`yyyymmdd`) tag if you wanna specific environment or testing.

## Architectures

Just use the `latest` tag, it will choose the right architecture automatically.

* amd64
* arm64

## Use this container in actions

Just add `container: ghcr.io/xlionjuan/fedora-createrepo-image:latest` after `runs-on: ubuntu-24.04-arm`, if your workflows doesn't need x86 runners, I recommend to use ARM runners because it is using lower footprints.

```yml
jobs:
    build:
      runs-on: ubuntu-24.04-arm # Or ubuntu-latest if you really need x86 runners
      container: ghcr.io/xlionjuan/fedora-createrepo-image:latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v4
      .....
      .....
```

## Verify the container

The container will be signed with [cosign](https://github.com/sigstore/cosign) and [GitHub Attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds), you can verify the container before you using it in the workflow.

This is an example workflow for verifying the container before using the container.

```yaml
jobs:
    verify:
      name: Verify container
      runs-on: ubuntu-24.04-arm
      steps:
        # If you want to use cosign to verify the container, you should install cosign first.

        # You only need to choose one method

        - name: Install Cosign
          uses: sigstore/cosign-installer@v3.7.0

        - name: Verify with cosign
          run: |
            cosign verify --rekor-url=https://rekor.sigstore.dev \
            --certificate-identity-regexp "https://github.com/xlionjuan/.*" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            ghcr.io/xlionjuan/fedora-createrepo-image:latest

        # Unfortunately, gh can't do anything without login, even just `gh attestation verify` command
        # so it needs to login, but NO any permissions are required.

        - name: Verify with gh
          env:
            GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          run: gh attestation verify --owner xlionjuan oci://ghcr.io/xlionjuan/fedora-createrepo-image:latest

    build:
      runs-on: ubuntu-24.04-arm
      needs: verify # So this will only runs if "verify" is passed.
      container: ghcr.io/xlionjuan/fedora-createrepo-image:latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v4

        - name: Do something
          run: rpm -qa
```
