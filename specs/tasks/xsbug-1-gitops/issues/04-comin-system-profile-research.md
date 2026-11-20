# Can comin deploy to the system profile on WSL?

Type: research
Status: resolved
Blocked by: none

## Question

Before running the restart test, establish from primary sources how comin's deployments could survive a NixOS-WSL distro restart. The underlying problem is that comin writes `system-profiles/comin` while the NixOS-WSL shim activates `profiles/system` ([ADR 0003](../../../adr/0003-comin-for-gitops-pending-wsl-restart-test.md), [research §4](../../../projects/research-nixos-wsl-comin-bootstrap.md#wsl2-specific-concerns)).

- Has comin (`main`, open PRs, issues #144 and #86) added or planned a way to deploy into the `system` profile?
- Is mitigation (a) safe: a `postDeploymentCommand` that runs `nix-env -p /nix/var/nix/profiles/system --set "$(readlink -f /run/current-system)"`? Consider generation numbering, garbage collection, `nixos-rebuild --rollback` and the testing branch.
- Does NixOS-WSL offer any hook to activate a different profile at start?
- Which concrete checks should the restart test run, and what results should it expect?

## Answer

Resolved 2026-11-19 by a research agent.

**Findings:** [research-comin-system-profile-wsl.md](../../../projects/research-comin-system-profile-wsl.md), kept next to the first research note. It was first written on a throwaway research branch (commit `ba778b9`), which has since been deleted.

- **comin won't write the `system` profile on Linux.** `system-profiles/comin` is hard-coded on `v0.14.0` and `main`. The maintainer's position (#144, #86, #109) is that tools reading only `system` should be fixed. PR #232 writes `system` for nix-darwin only (opened 2026-11-18, unreviewed). PR #197 plans to suspend comin when the running system differs from its last deployment.
- **The ADR 0003 hook has a bug.**
  - It reads `/run/current-system`, which still holds the *old* system when comin turns a `switch` into a `boot` because switch inhibitors changed. In that case the new generation never takes effect on WSL.
  - Its output is also logged only at debug level.
  - **Corrected hook "a′"** (findings §2.6): it reads `system-profiles/comin`, takes the main-branch names from the comin config, refuses the `test` operation on main, does nothing when `system` already points at the target, and logs through `logger`. With `nix.gc --delete-older-than` it is safe for generation numbering, `list-generations`, `--rollback` and GC. There's no race with comin's own profile write.
- **NixOS-WSL always starts `profiles/system`.** No option, hook or open issue changes that.
- **Fallback "a″"** (findings §2.7): `mkForce` NixOS-WSL's no-op `installBootLoader` so it sets the `system` profile, as the nixpkgs LXC module does. The downside is that a failed switch persists, as with `nixos-rebuild`.
- **Restart-test checklist** (findings §4), used by "Run the WSL restart test":
  - **Run A, no mitigation:** expected to revert to the last manual generation. Recover with `comin deployment submit-latest`.
  - **Run B, with a′:** covers the testing branch, a failed deployment, a forced `boot`, GC and rollback.
  - **Trap:** don't push a pure revert after a failed deployment (comin #192).
