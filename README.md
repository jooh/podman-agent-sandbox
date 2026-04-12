# agdev

This repo bootstraps a dedicated rootless Podman machine for Apple silicon macOS development setups. The supported baseline is a named VM, `dev-agents` by default, with zero configured host shares.

## What The Repo Provides

- `Brewfile` installs the required host tools: `podman` and `jq`.
- `scripts/bootstrap-podman-machine` creates or starts the hardened machine and runs verification.
- `scripts/verify-podman-machine` checks the machine's hardening invariants.
- `scripts/diagnose-podman-machine-lifecycle` runs a scratch-machine lifecycle matrix across zero-mount, one-share, and Podman-default profiles.
- `scripts/diagnose-podman-machine-nomount` keeps the older two-case zero-mount versus one-share comparison.
- `config/podman-machine.containers.conf` is the scoped machine config template used only during `podman machine init`.
- `config/podman-agent-machine.playbook.yml` is an optional first-boot playbook for a dedicated `testrunner` user and rootless `podman.socket`.

## Supported Baseline

Bootstrap does not overwrite `~/.config/containers/containers.conf`. It renders a temporary `containers.conf`, passes it to `podman machine init` via `CONTAINERS_CONF`, and appends `volumes = []` so the machine is created without Podman's broad default macOS shares or any repo-specific replacement share.

The verification script enforces the current baseline:

- the machine exists, is running, and has no failed systemd units
- the machine is rootless
- default broad macOS mount sources are absent
- zero configured host mounts are present
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

Run the lifecycle investigation matrix:

```bash
./scripts/diagnose-podman-machine-lifecycle
```

Run the older zero-mount versus one-share comparison:

```bash
./scripts/diagnose-podman-machine-nomount
```

The lifecycle harness writes artifacts under `artifacts/podman-machine-investigate/<machine-prefix>/` and captures first-boot and second-boot state across multiple mount profiles. The older two-case diagnostic writes artifacts under `artifacts/podman-machine-diagnose/<machine-prefix>/`.

Both workflows capture:

- generated machine config and ignition files
- `podman machine inspect` output and state polling
- host `vfkit`, `gvproxy`, and macOS unified logs when available
- guest `journalctl` and `systemctl` output when SSH becomes available

Use that workflow when a machine fails early enough that normal guest inspection is incomplete.

## Useful Overrides

- `SKIP_BREW=1` skips `brew bundle check/install`.
- `PODMAN_ROOTFUL_SOCKET_PATH` changes the guest rootful socket path checked by verification.
- `PODMAN_TESTRUNNER_SOCKET_PATH` changes the guest `testrunner` socket path checked by `--require-testrunner`.
- `MACOS_LOG_COMMAND` changes the host log command used by the diagnostic scripts.

Generated local paths:

- `artifacts/` stores diagnostic output and is ignored by git.

## Repo Maintenance Checks

For doc and script changes, the cheap repo-local checks are:

```bash
bash -n scripts/bootstrap-podman-machine \
  scripts/verify-podman-machine \
  scripts/diagnose-podman-machine-lifecycle \
  scripts/diagnose-podman-machine-nomount \
  scripts/check-hardcoded-absolute-paths \
  scripts/lib/podman-machine-paths.sh

./scripts/check-hardcoded-absolute-paths

./scripts/bootstrap-podman-machine --help
./scripts/verify-podman-machine --help
./scripts/diagnose-podman-machine-lifecycle --help
./scripts/diagnose-podman-machine-nomount --help
```
