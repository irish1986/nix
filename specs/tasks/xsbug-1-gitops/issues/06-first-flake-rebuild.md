# First flake rebuild on xsbug-1

Type: task (HITL)
Status: open
Blocked by: 02, 03, 05

## Question

Turn the stock distro into `xsbug-1` from the pushed flake. The agent writes `docs/how-to/first-flake-rebuild.md`; the user runs every command.

1. Enable flakes on the stock image.
2. Run `sudo nixos-rebuild boot --flake github:irish1986/nixos#xsbug-1`. Use `boot`, not `switch`, because the Account changes from `nixos` to `irish` ([change-username](https://github.com/nix-community/NixOS-WSL/blob/05721a428830972f025a8575b1a19c418d422d1b/docs/src/how-to/change-username.md)).
3. Follow the documented restart sequence.
4. Log in as `irish`.
5. Verify the hostname, home-manager files and `nixos-rebuild list-generations`.

Then make one small change on the workbench, push it, and apply it with `nixos-rebuild switch --flake github:…` to feel the manual loop before automating it. Fix the build errors the skeleton will probably hit.

**Done when:** `xsbug-1` boots from the flake as `irish` with the minimal Person setup, and the manual loop worked once.
