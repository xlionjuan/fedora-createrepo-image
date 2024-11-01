# fedora-createrepo-image

[![Build all](https://github.com/xlionjuan/fedora-createrepo-image/actions/workflows/build_all.yml/badge.svg)](https://github.com/xlionjuan/fedora-createrepo-image/actions/workflows/build_all.yml)

Build very small Fedora based container image just for creating and building [RPM](https://github.com/xlionjuan/rustdesk-rpm-repo/tree/main/createrepo) and also [APT repo](https://github.com/xlionjuan/apt-repo-action).

By creating and using this container images, it can save ***time, resources and energy***, because it won't need to update package lists and install dependencies every times when it runs.

I mainly use it on all of my RustDesk repos. (Check my profile)

## Frequency

Build once a ~~month~~ week. (I bump to Fedora 41 early for testing dnf5 changes)

## Installed packages

Please refer to [Dockerfile](fe/Dockerfile).

## Tagging
The latest will be `latest`, and a date (`yyyymmdd`) tag if you wanna specific environment or testing.

## Use this container in actions
Just add `container: ghcr.io/xlionjuan/fedora-createrepo-image:latest` or `container: ghcr.io/xlionjuan/fedora-createrepo-image-minimal:latest` after `runs-on: ubuntu-latest`, I recommend you to use `ubuntu-latest` to ensure the Docker Engine is the latest version.

```yml
jobs:
    build:
      runs-on: ubuntu-latest
      container: ghcr.io/xlionjuan/fedora-createrepo-image-minimal:latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v4
      .....
      .....
```

Note: minimal image is using `microdnf` instead of `dnf`.
