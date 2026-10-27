# Repository Guidance

## Scope

This repository builds the container image used by Linux package repository workflows. Executable scripts under `scripts/` are public CI tools installed into the image's PATH.

Preserve compatibility with downstream workflows unless a coordinated caller migration is part of the change.

## Script Development and Validation

Before adding, changing, or reviewing a script, read the authoritative script manual, [docs/scripts.md](docs/scripts.md), for design rules, ownership boundaries, usage examples, and required checks. Read the general guidance and the reference sections for each affected script.

When changing the container's installed tools or runtime environment, also read that document's Container Integration section and the references for scripts that depend on those tools.

## Downstream Compatibility

The following repositories depend on this image and its CI tools:

- [rustdesk-apt-repo-latest](https://github.com/xlionjuan/rustdesk-apt-repo-latest)
- [rustdesk-apt-repo-nightly](https://github.com/xlionjuan/rustdesk-apt-repo-nightly)
- [rustdesk-rpm-repo](https://github.com/xlionjuan/rustdesk-rpm-repo)
- [ntpd-rs-repos](https://github.com/xlionjuan/ntpd-rs-repos)

For API/ABI or other compatibility-sensitive changes, inspect the callers in all four repositories to identify affected workflows. This includes script names and flags, stdout formats, exit statuses, environment variables, generated files, signing/key-store behavior, and installed tool versions or backends.

For each affected workflow, either preserve its existing contract or coordinate the downstream update with this change. Validate the image/scripts together with the affected caller flows, using throwaway packages and keys for signing checks. Before merge, record which downstream callers were checked, any required companion changes, the validation results, and any checks still blocked or pending. Local checks alone do not establish downstream compatibility.
