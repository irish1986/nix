# Write the flake skeleton for xsbug-1

Type: task (HITL)
Status: open
Blocked by: 01

## Question

Write the first real configuration in the [ADR 0005](../../../adr/0005-host-role-feature-layout.md) layout, just enough for `xsbug-1`. The agent writes and explains each file; the user reviews and commits.

- `flake.nix` with inputs pinned as in [research §5](../../../projects/research-nixos-wsl-comin-bootstrap.md#5-recommended-repo-and-flake-layout): nixpkgs `nixos-26.05`, NixOS-WSL `release-26.05`, home-manager `release-26.05`, comin `v0.14.0`, each with `follows`.
- `lib/mkHost.nix`, which adds the Base Role, home-manager and the comin module. comin stays disabled until the "Enable comin and watch a push arrive" ticket.
- `modules/roles/{base,wsl,home}.nix`.
- `my.accounts.<name>` options that attach a Person to an Account.
- `people/simon/` as decided in "Decide the minimal Person setup".
- `hosts/xsbug-1/default.nix` with Account `irish`, plus a `hosts/xsbug-1/wslconfig` reference copy.

**Done when:** the user can explain what each file does, and the skeleton is committed and merged to `main`. It is not built here; the first build happens in "First flake rebuild on xsbug-1".
