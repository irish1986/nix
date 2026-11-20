# Write the flake skeleton for xsbug-1

Type: task (HITL)
Status: resolved
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

## Answer

Resolved 2026-11-19. The agent wrote the skeleton; the user reviewed it and asked for it to be committed.

- **Files:**
  - `flake.nix`, with inputs pinned: nixpkgs, NixOS-WSL and home-manager on 26.05, comin `v0.14.0`, each with `follows`.
  - `lib/mkHost.nix`, which sets the hostname and adds home-manager, the comin module (not enabled) and the Base Role.
  - `modules/roles/{base,wsl,home}.nix`.
  - `modules/accounts.nix`, the `my.accounts.<username> = { person; admin; }` mechanism, imported by the Base Role.
  - `modules/features/vscode-remote.nix` (nix-ld + wget).
  - `people/simon/{default.nix,p10k.zsh}`.
  - `hosts/xsbug-1/{default.nix,wslconfig}`.
- **Verified against source** at the pinned refs: home-manager `programs.git.settings.user.*` (replaces `userName`/`userEmail`), zsh `autosuggestion`/`syntaxHighlighting`/`initContent`/`oh-my-zsh`/`plugins`, `programs.vim.defaultEditor`, `home-manager.nixosModules.home-manager`, `nixos-wsl.nixosModules.default`, `comin.nixosModules.comin`, `programs.nix-ld.enable`, and the `zsh-powerlevel10k` theme path.
- **Not evaluated or built:** there's no Nix on the workbench. Errors will surface in "First flake rebuild on xsbug-1".
- **Deliberately left out:** the nixos-unstable package set (until a package needs it), time zone and locale (defaults apply), and enabling comin.
- **Placement and defaults:**
  - `modules/accounts.nix` is a mechanism, not a Feature, so it lives outside `features/` and `roles/`.
  - Every Account's login shell is zsh until a Person needs something else.
- **Gap found:** there is no `flake.lock`. It was added as a step in "First flake rebuild on xsbug-1".
