# Can comin deploy to the system profile on WSL?

Type: research
Status: open
Blocked by: none

## Question

Before running the restart test, establish from primary sources how comin's deployments could survive a NixOS-WSL distro restart. The underlying problem is that comin writes `system-profiles/comin` while the NixOS-WSL shim activates `profiles/system` ([ADR 0003](../../../adr/0003-comin-for-gitops-pending-wsl-restart-test.md), [research §4](../../../projects/research-nixos-wsl-comin-bootstrap.md#wsl2-specific-concerns)).

- Has comin (`main`, open PRs, issues #144 and #86) added or planned a way to deploy into the `system` profile?
- Is mitigation (a) safe: a `postDeploymentCommand` that runs `nix-env -p /nix/var/nix/profiles/system --set "$(readlink -f /run/current-system)"`? Consider generation numbering, garbage collection, `nixos-rebuild --rollback` and the testing branch.
- Does NixOS-WSL offer any hook to activate a different profile at start?
- Which concrete checks should the restart test run, and what results should it expect?
