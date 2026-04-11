# Hardened Podman Machine Plan for macOS Dev Setups

## Goal

Provide a repeatable way for developers on Apple silicon Macs to install Podman with Homebrew, create a dedicated hardened Podman VM for agent and containerized test workloads, and keep that setup versioned in-repo so it can be recreated consistently.

This plan is aimed at a threat model where:

- workloads should be isolated from the host macOS system by a VM boundary
- the Podman VM should not expose the developer's home directory by default
- developers may need to run tests that invoke `podman run` or `podman exec`
- different Podman machines may be used for different trust zones

## Current Implementation Direction

This repo now implements the plan in two phases:

- phase 1 creates and verifies a hardened rootless machine called `dev-agents`
- phase 2 is opt-in guest provisioning with a first-boot playbook for a dedicated `testrunner` user

The bootstrap path defaults to phase 1 only. Guest provisioning is enabled explicitly with `--with-playbook` on first create so the secure baseline stays small and predictable.

On the current locally validated Podman `5.8.1` setup, a machine created with `volumes = []` never completed boot and dropped into Ignition emergency mode. The implemented baseline therefore uses one narrow dedicated host share instead of zero mounts.

## Design Summary

### Recommended approach

Use:

- Homebrew Bundle to install the required binaries
- a repo-managed bootstrap script to configure the host and create the Podman machine
- a versioned `containers.conf` template used only for machine creation
- an optional Podman machine playbook for guest-side provisioning on first boot

### Why this split

Homebrew is good at installing packages, but Podman machine state is user-scoped and created after install. The VM itself should be treated as provisioned infrastructure, not as something implicitly owned by `brew install podman`.

The repo implementation does not overwrite `~/.config/containers/containers.conf`. Instead, it scopes the hardening config to `podman machine init` by setting `CONTAINERS_CONF` for that command only. That avoids globally changing unrelated local Podman workflows.

That means the reproducible unit is:

1. install tools
2. write host-side Podman config
3. create a named machine with the expected settings
4. provision the guest
5. verify the hardening state

## Threat Model

### What this setup protects against

- a containerized agent compromising its own container
- a nested container workflow compromising the dev container or the Podman service inside the guest VM
- accidental exposure of the developer's home directory to the guest VM

### What this setup does not fully protect against

- compromise of the macOS user account that administers the Podman machines
- vulnerabilities in the hypervisor or VM bridge components
- deliberate host integration that reintroduces trust channels, such as bind mounts, forwarded credentials, or exposed Podman sockets

## Core Security Principles

### 1. Use a dedicated Podman machine for risky workloads

Create a separate Podman machine for agent or test execution instead of reusing the general-purpose machine.

Example trust zones:

- `dev-default`: ordinary development containers
- `dev-agents`: hardened machine for agents

### 2. Remove default host mounts

Do not allow the Podman VM to mount `/Users`, `/private`, `/var/folders`, or the developer's full home directory unless explicitly required.

This is the most important hardening change relative to the default convenience-oriented setup.

### 3. Keep the machine rootless where possible

Prefer the default rootless mode for the machine and for guest-side Podman workflows unless there is a specific requirement for rootful execution.

### 4. Avoid leaking the main Podman socket

Do not mount the main Podman socket into untrusted containers. If tests need to run `podman run` or `podman exec`, prefer a dedicated rootless Podman service owned by a separate unprivileged user in the guest VM.

### 5. Prefer narrow workspaces over broad host sharing

If a host bind mount is needed, share only a dedicated disposable workspace path rather than broad host directories.

## Repository Layout

```text
repo/
  Brewfile
  TESTS.md
  scripts/
    bootstrap-podman-machine
    verify-podman-machine
  config/
    podman-machine.containers.conf
    podman-agent-machine.playbook.yml
  hardened-podman-machine-plan.md
```

## Setup Flow

### Step 1: Install tools with Homebrew

Use a repo `Brewfile` to install the CLI tooling.

Example:

```ruby
brew "podman"
brew "yq"
brew "jq"
```

Optional:
- add any internal helper CLI from a custom tap
- add other validation tools used by the bootstrap or verification scripts

### Step 2: Prepare scoped machine config

Keep the hardening config in the repo and use it only during machine creation.

Initial hardened template:

```toml
[machine]
# bootstrap appends one dedicated host share at runtime
```

Bootstrap renders a temporary machine config that mounts a single dedicated host path into an existing guest path such as `/Users`. On the current Podman release, custom machine mounts proved sensitive to guest target path selection, so verification checks the host-side source path from `podman machine inspect` instead of inferring exposure from the guest mountpoint name alone.

Optional additions may include resource sizing and Rosetta behavior depending on the team's requirements.

### Step 3: Create a named hardened machine

Create a dedicated machine for agents or risky workloads.

Example:

```bash
CONTAINERS_CONF=./config/podman-machine.containers.conf \
  podman machine init dev-agents

podman machine start dev-agents
```

Opt in to guest provisioning on first create:

```bash
CONTAINERS_CONF=./config/podman-machine.containers.conf \
  podman machine init --playbook ./config/podman-agent-machine.playbook.yml dev-agents
```

### Step 4: Provision the guest VM

Use the optional first-boot playbook to perform guest-side setup such as:

- creating a dedicated unprivileged test user
- enabling a rootless `podman.socket` for that user
- installing any guest-side packages needed for test execution
- applying guest-side container engine configuration if required

### Step 5: Verify the machine state

Validate that:

- the intended machine is running
- the machine does not expose broad host paths
- the machine exposes at most one dedicated narrow host share
- the machine is using the intended rootless configuration
- the rootful Podman socket is absent
- the host and guest Podman versions match
- the expected guest user and Podman socket exist
- no unexpected privileged settings are enabled

Suggested checks:

```bash
podman machine ssh dev-agents mount
podman machine ssh dev-agents ls /Users
podman machine ssh dev-agents id
```

## Bootstrap Script Responsibilities

The bootstrap script should be idempotent and should do the following:

1. install packages from the `Brewfile`
2. create the Podman machine with the scoped `containers.conf` if it does not exist
3. optionally apply the guest playbook on first create
4. start the machine
5. run verification checks
6. fail clearly if the machine drifts from the expected hardening state

A simple shape is:

```bash
#!/usr/bin/env bash
set -euo pipefail

brew bundle check --file ./Brewfile || brew bundle install --file ./Brewfile

if ! podman machine inspect dev-agents >/dev/null 2>&1; then
  CONTAINERS_CONF=./config/podman-machine.containers.conf \
    podman machine init dev-agents
fi

podman machine start dev-agents
./scripts/verify-podman-machine dev-agents
```

## Supporting `podman run` and `podman exec` Inside a Dev Container

### Recommended pattern

Do not run a full nested Podman engine unless the test suite absolutely requires it.

Prefer:

- a Podman client inside the dev container
- a dedicated rootless Podman service inside the Podman VM
- a dedicated unprivileged guest user that owns that service

This gives tests `podman run` and `podman exec` behavior with a smaller privilege footprint than true Podman-in-Podman.

### Why this is preferred

True Podman-in-Podman often requires elevated allowances or special devices. A remote client talking to a dedicated rootless service keeps the authority narrower and easier to reason about.

### Operational pattern

Inside the guest VM:

- create user `testrunner`
- enable `podman.socket` for that user
- keep that socket separate from the default user and from any rootful Podman service

Inside the dev container, only if a container really needs Podman access:

- install `podman-remote`
- mount only the dedicated `testrunner` socket
- point `CONTAINER_HOST` at that dedicated socket
- avoid mounting the main Podman socket

Example environment:

```bash
export CONTAINER_HOST=unix:///run/user/1001/podman/podman.sock
```

## VS Code Integration

### Recommended workflow

Treat this as a later workflow, not part of phase 1 hardening.

Prefer this flow instead of manually running a standalone VS Code Server inside the container:

1. connect the native VS Code desktop client to the Podman VM with Remote - SSH
2. from that remote context, reopen the project in a dev container or attach to a running container
3. let VS Code manage the server-side components automatically

This keeps the VM as the remote boundary and the container as the inner development environment.

### Why this is preferred

This approach is simpler and more supportable than treating VS Code Server as an application you manually deploy inside the container.

Benefits:

- the VM remains the SSH target
- the container remains disposable
- the native VS Code UI can connect cleanly to the environment inside the VM
- developers can use standard Remote - SSH and Dev Containers workflows

### Podman-specific notes

For Podman-based dev containers, configure VS Code Dev Containers to use `podman` rather than Docker where needed.

The intended model is:

- SSH target: the Podman VM
- dev environment: a container running inside that VM
- VS Code server lifecycle: managed by VS Code, not by a separate manual service deployment

### When to avoid a standalone server in the container

Avoid manually hosting a separate long-lived VS Code Server process inside the container unless there is a very specific requirement for that architecture. For this developer setup, the standard Remote - SSH plus Dev Containers pattern should be the default.

## Multiple Podman Machines for Different Threat Models

Using multiple named machines on the same host is recommended when different workloads need different trust assumptions.

Examples:

- `dev-default`: normal developer convenience setup
- `dev-agents`: no host mounts, narrow test socket exposure

Developers can switch active connections explicitly rather than trying to force one machine to fit every workload.

## Team Distribution Strategy

### What to version in Git

Version these files in the repo:

- `Brewfile`
- bootstrap and verification scripts
- host-side `containers.conf` template
- Podman machine playbook
- this markdown plan

### What not to rely on

Do not rely on:

- manual per-developer machine setup
- implicit defaults from `brew install podman`
- ad hoc guest-side SSH configuration done by hand

### Optional enhancement: internal helper CLI

If the team wants a cleaner interface, ship a small internal helper command via a Homebrew tap.

Example user flow:

```bash
brew install company/tap/dev-env
company-dev-env setup-podman-agent-machine
```

That helper should still be a thin wrapper around versioned repo logic, not a hidden snowflake installer.

## Proposed Milestones

### Milestone 1: Minimal reproducible hardening

Deliver:

- `Brewfile`
- `config/podman-machine.containers.conf` as the base for the rendered machine config
- `scripts/bootstrap-podman-machine`
- `scripts/verify-podman-machine`
- `TESTS.md`

Success criterion:
- a developer can create a hardened Podman machine with no broad host mounts, one dedicated narrow share, no rootful socket, and matching host/guest Podman versions

### Milestone 2: Guest provisioning

Deliver:

- first-boot playbook
- dedicated `testrunner` guest user
- rootless `podman.socket` for that user

Success criterion:
- test workloads can run `podman run` and `podman exec` through a dedicated rootless service

### Milestone 3: Multi-machine support

Deliver:

- support for creating multiple named machines
- machine selection logic for different workflows

Success criterion:
- developers can choose between convenience-oriented and hardened machines without manual reconfiguration

### Milestone 4: Drift detection and re-creation

Deliver:

- verification logic that detects undesired mounts or configuration drift
- clear remediation instructions
- optional automatic recreate flow for disposable machines

Success criterion:
- the machine can be rebuilt predictably when it drifts or becomes contaminated

## Open Questions

1. Does the team need Rosetta enabled inside the Podman machine for x86_64 Linux binaries, or can it be disabled?
2. Does the team need any host workspace path mounted into the hardened machine, or can all file transfer happen through controlled copy operations?
3. Do the test suites need a remote Podman client only, or do any tests truly require full nested Podman behavior?
4. Should the hardened machine be disposable and recreated often, or should it be treated as a longer-lived asset?
5. Should machine creation be owned entirely by the repo bootstrap, or wrapped in an internal Homebrew-installed helper command?

## References

- `podman machine init` docs for current defaults and `--playbook`: https://docs.podman.io/en/latest/markdown/podman-machine-init.1.html
- `podman system service` docs for rootless socket behavior: https://docs.podman.io/en/latest/markdown/podman-system-service.1.html

## Recommended First Implementation

Start with the smallest useful secure baseline:

- one dedicated machine called `dev-agents`
- scoped machine config rendered to one dedicated narrow share
- bootstrap script that creates and starts that machine
- verification script that confirms there are no broad host mounts
- no nested Podman engine
- tests use a dedicated rootless Podman service only if needed

This gives a clear foundation that can later grow into a fuller developer platform pattern.
