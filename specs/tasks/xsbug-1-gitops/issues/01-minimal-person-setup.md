# Decide the minimal Person setup

Type: grilling
Status: resolved
Blocked by: none

## Question

What exactly goes into `people/simon/` for the destination, so the flake skeleton can be written? Settle:

- **Shell:** zsh as on Ubuntu, bash or fish, and how much shell config to carry over.
- **Editor:** a terminal editor inside NixOS (neovim, helix, …), or VS Code Remote-WSL from Windows, which needs `programs.nix-ld` ([research §2](../../../projects/research-nixos-wsl-comin-bootstrap.md#limitations-and-known-issues)).
- **git identity:** which name and email appear in a public repo, e.g. the GitHub noreply address.
- What stays out and goes to the [port-daily-setup intent](../../../intents/port-daily-setup.md).

## Answer

Resolved 2026-11-19 by grilling.

- **Shell:** zsh through home-manager, with oh-my-zsh (`git`, `sudo` and `history` plugins), autosuggestions, syntax-highlighting and the existing powerlevel10k prompt. `.p10k.zsh` is copied from the workbench into `people/simon/`.
- **Editor:**
  - vim is `$EDITOR` on xsbug-1, so it works even in the recovery shell or when the VS Code server breaks.
  - VS Code Remote-WSL is supported through a `vscode-remote` Feature (`programs.nix-ld` plus `wget`), included by the `wsl` Platform Role, so every WSL Host gets it.
- **git identity:** name "Simon Harvey", email `13018674+irish1986@users.noreply.github.com` (GitHub noreply). It is set in the Person setup. An Account or a Kind Role may override it later, e.g. a work email on a Work Host.
- **Public history:** this repo's local git `user.email` switches to the noreply address now. The three existing commits get their author rewritten to it in "Publish the repo to GitHub", before the first push.
- **Parked** in the [port-daily-setup intent](../../../intents/port-daily-setup.md): the oh-my-zsh `vscode`, `you-should-use` and `command-not-found` plugins (command-not-found works differently on NixOS).
- No ADR: every choice here is easy to reverse.
