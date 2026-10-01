# Home Manager for irish. Keep this file portable (no wsl.* or /mnt/c) so it can
# be reused on bare-metal NixOS or a Mac; WSL glue lives in ./wsl.nix.
{ pkgs, inputs, ... }:
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
    ./git.nix
    ./shell.nix
    ./ssh.nix
  ];

  home = {
    # The Home Manager release first activated. Never bump it.
    stateVersion = "26.05";

    packages = with pkgs; [
      # Everyday CLI
      ripgrep
      fd
      jq
      yq
      eza
      bat
      tmux
      htop
      just

      # Toolchains, pinned by flake.lock
      rustup # run `rustup default stable` once
      nodejs_24
      python3
      uv
      ansible
    ];

    # Self-updating tools (claude, copilot) install into ~/.local/bin, and
    # `npm install -g` goes to ~/.npm-global because the Nix store is read-only.
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.npm-global/bin"
    ];
    file.".npmrc".text = ''
      prefix=''${HOME}/.npm-global
    '';
  };

  programs = {
    gh.enable = true; # also the git credential helper for github.com
    fzf.enable = true;
    zoxide.enable = true; # `z <dir>`; plain `cd` is left alone
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    # `, <program>` runs anything in nixpkgs without installing it.
    nix-index-database.comma.enable = true;
  };
}
