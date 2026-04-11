# agdev

This repo bootstraps a dedicated rootless Podman machine for Apple silicon macOS development setups. The supported baseline is a named VM, `dev-agents` by default, that avoids Podman's broad default macOS shares and instead exposes at most one dedicated workspace share.

## What The Repo Provides

- `Brewfile` installs the required host tools: `podman` and `jq`.
- `scripts/bootstrap-podman-machine` creates or starts the hardened machine and runs verification.
- `scripts/verify-podman-machine` checks the machine's hardening invariants.
- `scripts/diagnose-podman-machine-nomount` compares a zero-mount scratch machine against the repo's one-share baseline and captures host and guest artifacts.
- `config/podman-machine.containers.conf` is the scoped machine config template used only during `podman machine init`.
- `config/podman-agent-machine.playbook.yml` is an optional first-boot playbook for a dedicated `testrunner` user and rootless `podman.socket`.

## Supported Baseline

Bootstrap does not overwrite `~/.config/containers/containers.conf`. It renders a temporary `containers.conf`, passes it to `podman machine init` via `CONTAINERS_CONF`, and appends one dedicated host share sourced from `.podman-machine-share/` unless `PODMAN_HOST_SHARE_DIR` overrides it.

The verification script enforces the current baseline:

- the machine exists, is running, and has no failed systemd units
- the machine is rootless
- default broad macOS mount sources are absent
- at most one dedicated host share is configured
- the configured rootful Podman socket is absent in the guest
- host and guest Podman versions match

`--with-playbook` adds one optional layer on first create: a `testrunner` guest user with a per-user `podman.socket`. That state is checked with `./scripts/verify-podman-machine --require-testrunner <machine-name>`.

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

Apply the optional guest playbook on first create:

```bash
./scripts/bootstrap-podman-machine --with-playbook
```

`--with-playbook` only works while creating a new machine. Recreate the machine if you need to reprovision it.

## Verification And Diagnostics

Run the verifier directly:

```bash
./scripts/verify-podman-machine dev-agents
```

Require the optional `testrunner` state:

```bash
./scripts/verify-podman-machine --require-testrunner dev-agents
```

Investigate zero-mount versus one-share behavior:

```bash
./scripts/diagnose-podman-machine-nomount
```

The diagnostic script creates two fresh scratch machines, writes artifacts under `artifacts/podman-machine-diagnose/<machine-prefix>/`, and captures:

- generated machine config and ignition files
- `podman machine inspect` output and state polling
- host `vfkit`, `gvproxy`, and macOS unified logs when available
- guest `journalctl` and `systemctl` output when SSH becomes available

Use that workflow when a machine fails early enough that normal guest inspection is incomplete.

## Useful Overrides

- `SKIP_BREW=1` skips `brew bundle check/install`.
- `PODMAN_HOST_SHARE_DIR` changes the dedicated host directory shared into the VM.
- `PODMAN_GUEST_SHARE_DIR` changes the guest mount target for that share.
- `PODMAN_ROOTFUL_SOCKET_PATH` changes the guest rootful socket path checked by verification.
- `PODMAN_TESTRUNNER_SOCKET_PATH` changes the guest `testrunner` socket path checked by `--require-testrunner`.
- `MACOS_LOG_COMMAND` changes the host log command used by the diagnostic script.

Generated local paths:

- `.podman-machine-share/` is the default dedicated host share directory.
- `artifacts/` stores diagnostic output and is ignored by git.

## Repo Maintenance Checks

For doc and script changes, the cheap repo-local checks are:

```bash
bash -n scripts/bootstrap-podman-machine \
  scripts/verify-podman-machine \
  scripts/diagnose-podman-machine-nomount \
  scripts/check-hardcoded-absolute-paths \
  scripts/lib/podman-machine-paths.sh

./scripts/check-hardcoded-absolute-paths

./scripts/bootstrap-podman-machine --help
./scripts/verify-podman-machine --help
./scripts/diagnose-podman-machine-nomount --help
```
