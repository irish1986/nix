# Settings every NixOS host gets, WSL or not.
{ pkgs, username, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      username
    ];
    auto-optimise-store = true;
  };

  # nh wraps nixos-rebuild and cleans old generations. Its cleaner replaces
  # nix.gc, so keep nix.gc off.
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 14d --keep 5";
    };
    flake = "/home/${username}/git/irish1986/nix";
  };

  programs.zsh.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  environment.enableAllTerminfo = true;
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
  ];
}
