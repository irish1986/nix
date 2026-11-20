# Decide the minimal Person setup

Type: grilling
Status: open
Blocked by: none

## Question

What exactly goes into `people/simon/` for the destination, so the flake skeleton can be written? Settle:

- **Shell:** zsh as on Ubuntu, bash or fish, and how much shell config to carry over.
- **Editor:** a terminal editor inside NixOS (neovim, helix, …), or VS Code Remote-WSL from Windows, which needs `programs.nix-ld` ([research §2](../../../projects/research-nixos-wsl-comin-bootstrap.md#limitations-and-known-issues)).
- **git identity:** which name and email appear in a public repo, e.g. the GitHub noreply address.
- What stays out and goes to the [port-daily-setup intent](../../../intents/port-daily-setup.md).
