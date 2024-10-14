# fedora-createrepo-image

[![Build and Push Docker Image](https://github.com/xlionjuan/fedora-createrepo-image/actions/workflows/build.yml/badge.svg)](https://github.com/xlionjuan/fedora-createrepo-image/actions/workflows/build.yml)

Build very small Fedora based container image just for creating and building RPM repo.

I mainly use it on [xlionjuan/rustdesk-rpm-repo](https://github.com/xlionjuan/rustdesk-rpm-repo)

## Frequency

[Build once a month.](https://github.com/xlionjuan/fedora-createrepo-image/blob/main/.github/workflows/build.yml#L6)

## Tagging
The latest will be `latest`, and a date (`yyyymmdd`) tag if you wanna specific environment or testing.

## Use this container in actions
Just add `container: ghcr.io/xlionjuan/fedora-createrepo-image:latest` after `runs-on: ubuntu-latest`, I recommend you use `ubuntu-latest` to ensure the Docker Engine is the latest version.

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
