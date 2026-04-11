# Hardened Podman Machine Manual Tests

This repo uses manual red/green verification because the change target is a local Podman VM on macOS rather than unit-testable application code.

## Red Baseline

- [x] `podman machine init --help` on Podman `5.8.1` shows Podman's default broad host mounts.
- [x] `podman machine ssh podman-machine-default mount` on the existing local machine shows those broad host mounts exposed through `virtiofs`.
- [x] `./scripts/check-hardcoded-absolute-paths --expect-matches` found hardcoded absolute paths before this change.

These two checks demonstrate the insecure default this repo is meant to harden against.

## Green Checks

- [x] `bash -n scripts/bootstrap-podman-machine`
- [x] `bash -n scripts/check-hardcoded-absolute-paths`
- [x] `bash -n scripts/diagnose-podman-machine-nomount`
- [x] `bash -n scripts/verify-podman-machine`
- [x] `./scripts/check-hardcoded-absolute-paths` returns no matches
- [x] `SKIP_BREW=1 ./scripts/bootstrap-podman-machine dev-agents`
- [x] `./scripts/diagnose-podman-machine-nomount`
- [x] `./scripts/verify-podman-machine dev-agents` via bootstrap
- [ ] `./scripts/verify-podman-machine --require-testrunner dev-agents` after recreating `dev-agents` with `--with-playbook`

## Expected Results

- `dev-agents` is created rootless.
- `dev-agents` has no broad host mount sources matching the default macOS convenience shares.
- `dev-agents` may have one dedicated share sourced from `.podman-machine-share`, mounted inside the guest at the configured `PODMAN_GUEST_SHARE_DIR`.
- Host Podman version matches the Podman version reported inside the named VM.
- The configured rootful socket path is absent in the guest.
- The optional playbook creates `testrunner` and exposes the configured per-user Podman socket for that user.

## Notes

- The current implementation uses one dedicated host share sourced from `.podman-machine-share` and verifies the host-side mount source via `podman machine inspect`.
- `scripts/check-hardcoded-absolute-paths` enforces that the tracked docs, scripts, and config files do not reintroduce the removed absolute path literals.
- The repo now derives guest and guest-socket absolute paths from configurable path helpers instead of embedding them directly in the tracked files.
- On this host, `dev-agents` passes bootstrap-time verification but later shows as stopped in `podman machine list`; that durability issue was observed during testing and is not yet explained by the repo scripts.
- `scripts/diagnose-podman-machine-nomount` writes comparable artifacts for the zero-mount and control-share cases under `artifacts/podman-machine-diagnose/<machine-prefix>/`.
- The no-mount diagnostic captures host-side evidence even when guest SSH never comes up: the generated `.ign`, the `vfkit` serial log from the host temp directory, the `gvproxy` log when present, and the macOS unified log for `podman`, `vfkit`, and `gvproxy`.
- On 2026-04-11, a fresh diagnostic run on local Podman `5.8.1` produced healthy zero-mount and control-share scratch machines. Both cases reached SSH, reported no failed systemd units, and recorded `Ignition finished successfully`.
- In the fresh zero-mount case, the generated ignition still included `immutable-root-off.service` and `immutable-root-on.service` even though there were no `.mount` units. On this host those units did not prevent boot.
- The older emergency-mode failure therefore does not currently reproduce as “zero mounts are broken.” The remaining unresolved problem is why the previously created `dev-agents` machine logged an ignition emergency-mode boot while fresh scratch machines did not.
