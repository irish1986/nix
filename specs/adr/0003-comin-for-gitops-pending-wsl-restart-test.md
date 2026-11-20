# 0003. Use comin for GitOps, subject to a WSL restart test

- Status: Proposed (blocked on the restart test below)
- Date: 2026-11-19

## Context

The goal is a workstation that follows this git repository: a change merged to `main` reaches every machine without anyone running `nixos-rebuild` by hand. comin is a pull-based agent that polls git remotes and deploys `nixosConfigurations.<hostname>`. It refuses force-pushed `main` branches, can verify commit signatures (GPG or SSH), offers a manual approval gate (`deployConfirmer.mode = "manual"`), and supports a per-machine `testing-<hostname>` branch.

Reading the source turns up a likely WSL-specific problem. It has not been tested:

1. comin records its `switch` and `boot` deployments in its own profile, `/nix/var/nix/profiles/system-profiles/comin`, and never updates the main `system` profile.
2. On real NixOS that is fine, because bootloader builders include every profile. NixOS-WSL has no bootloader: at every distro start its shim activates `/nix/var/nix/profiles/system`.
3. So after an idle shutdown, `wsl --shutdown` or a Windows reboot, the machine likely comes back on the last manual `nixos-rebuild` generation.
4. comin then does not redeploy, because the out-path and operation match its last recorded deployment. The machine silently disagrees with `comin status` until the next commit.
5. comin `boot` deployments would probably never take effect on WSL, including `switch` operations that comin downgrades to `boot` when switch inhibitors change.

The same kind of bug is already reported for comin with lanzaboote (comin#144, comin#86).

Two further limits:

- comin only polls while the distro is running. WSL stops idle distros after 15 s and the VM after 60 s by default, and systemd services don't keep them alive.
- `system.autoUpgrade`, the alternative, writes the `system` profile and so survives restarts. But with input updates it can deploy a state that is not in git.

Evidence: [research note §4 and §6](../projects/research-nixos-wsl-comin-bootstrap.md#wsl2-specific-concerns).

## Decision

Use comin, pinned to `v0.14.0` (module `comin.nixosModules.comin`, `inputs.nixpkgs.follows = "nixpkgs"`), as the GitOps agent **if the restart test passes, or passes with mitigation (a)**.

**Restart test** (manual, on the first machine):

1. Deploy a commit through comin `switch`.
2. Run `wsl -t NixOS`, then start the distro again.
3. Compare `readlink /run/current-system` with `/nix/var/nix/profiles/system` and `/nix/var/nix/profiles/system-profiles/comin`, and check whether comin redeploys.

**Outcomes:**

- **Pass:** the system stays on the comin generation. Accept this ADR as written.
- **Fail:** retest with mitigation (a), a `postDeploymentCommand` that, on `COMIN_STATUS=done` for `main`, points the `system` profile at `/run/current-system`. If that passes, accept this ADR with the mitigation. If it doesn't, supersede this ADR with one that drops comin and uses `nixos-rebuild` by hand until upstream comin can target the `system` profile (option (b) in the research note).

**Settings, whatever the outcome:**

- `exporter.listen_address = "127.0.0.1"`. The default binds all interfaces, and the NixOS firewall is off under WSL.
- Commit signature verification (`sshAllowedSignersPath` or `gpgPublicKeyPaths`), knowing it checks only the tip commit. Deferred until right after the first Host syncs from git; see [intent](../intents/comin-commit-signing.md).
- A credential only for a private remote: a fine-grained read-only token or a read-only deploy key. The public repository (ADR 0004) needs none.
- Do not combine comin with `system.autoUpgrade`.
- Never ship `wsl.defaultUser` changes through comin. They need `boot` plus a restart, done by hand.

## Consequences

- Until the test runs, configuration changes are applied with `nixos-rebuild` by hand. Path A in ADR 0002 already works that way.
- Keeping the distro running long enough for comin to poll is a Windows-side setting (`instanceIdleTimeout`, or a logon task) and may be restricted by work Intune policy. A machine only catches up while the distro is open.
- Deleting `/var/lib/comin` lets the machine roll back to any older signed commit. Treat that directory as integrity-relevant state.
- Moving to comin `main` (for `nixosModules.default`, `postBuildCommand` and gRPC socket options) waits for the next comin tag.
