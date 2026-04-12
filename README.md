# agdev

This repo bootstraps a dedicated rootless Podman machine for Apple silicon macOS development setups. The supported baseline is a named VM, `dev-agents` by default, with zero configured host shares.

## What The Repo Provides

- `Brewfile` installs the required host tools: `podman` and `jq`.
- `scripts/bootstrap-podman-machine` creates or starts the hardened machine and runs verification.
- `scripts/verify-podman-machine` checks the machine's hardening invariants.
- `config/podman-machine.containers.conf` is the scoped machine config template used only during `podman machine init`.

## Supported Baseline

Bootstrap does not overwrite `~/.config/containers/containers.conf`. It renders a temporary `containers.conf`, passes it to `podman machine init` via `CONTAINERS_CONF`, and appends `volumes = []` so the machine is created without Podman's broad default macOS shares or any repo-specific replacement share.

The verification script enforces the current baseline:

- the machine exists, is running, and has no failed systemd units
- the machine is rootless
- default broad macOS mount sources are absent
- zero configured host mounts are present
- the configured rootful Podman socket is absent in the guest
- host and guest Podman versions match

## Quick Start

Create or start the default machine:

```bash
./scripts/bootstrap-podman-machine
```

Use a different machine name:

```bash
./scripts/bootstrap-podman-machine my-machine
```

Skip `brew bundle check/install` if the host tools are already installed:

```bash
SKIP_BREW=1 ./scripts/bootstrap-podman-machine
```

## Verification

Run the verifier directly:

```bash
./scripts/verify-podman-machine dev-agents
```

## Useful Overrides

- `SKIP_BREW=1` skips `brew bundle check/install`.
- `PODMAN_ROOTFUL_SOCKET_PATH` changes the guest rootful socket path checked by verification.

## Repo Maintenance Checks

For doc and script changes, the cheap repo-local checks are:

```bash
bash -n scripts/bootstrap-podman-machine \
  scripts/verify-podman-machine \
  scripts/check-hardcoded-absolute-paths \
  scripts/lib/podman-machine-paths.sh

./scripts/check-hardcoded-absolute-paths

./scripts/bootstrap-podman-machine --help
./scripts/verify-podman-machine --help
```
