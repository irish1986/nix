# Install stock NixOS-WSL beside Ubuntu

Type: task (HITL)
Status: open
Blocked by: none

## Question

Get a stock NixOS-WSL distro running on `XSBUG-1` next to `Ubuntu-26.04`, without touching Ubuntu or the default distro, and learn how to get out of trouble before changing anything.

The agent writes `docs/how-to/install-nixos-wsl.md` from the official [install guide](https://nix-community.github.io/NixOS-WSL/install.html) and [ADR 0002](../../../adr/0002-bootstrap-stock-image-then-custom-image.md) Path A. The user follows it and fixes it. It covers:

- downloading `nixos.wsl` from release `2605.7.2` and checking its `.sha256`;
- `wsl --install --from-file` with a name and location;
- first login as `nixos`;
- how to stop, start and unregister the distro;
- the recovery shell (`nixos-wsl-recovery`) and how to boot an older generation.

**Done when:** the user can start, stop and enter the NixOS distro, and has opened the recovery shell once. The answer records the distro name and install location.
