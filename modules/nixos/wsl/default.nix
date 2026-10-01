# Imported only by WSL hosts. Windows-wide settings (.wslconfig, Terminal,
# fonts) belong to the dotfiles repo, not here.
{
  inputs,
  pkgs,
  username,
  ...
}:
{
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  wsl = {
    enable = true;
    defaultUser = username;
    startMenuLaunchers = true;
    # Keep Windows' PATH out: it makes every completion scan /mnt/c. The few
    # Windows tools in use get wrappers in home/<user>/wsl.nix.
    wslConf.interop.appendWindowsPath = false;
    # Uncomment if `code` or other .exe files fail with "exec format error".
    # interop.register = true;
    # Uncomment if the user session times out after another distro started first (NixOS-WSL #888).
    # wslConf.boot.initTimeout = 30000;
  };

  # VS Code's remote server downloads a dynamically linked node, as do the
  # claude/copilot installers and uv-managed Pythons. nix-ld gives them the
  # standard loader. Never use services.envfs instead: it can stop WSL booting.
  programs.nix-ld.enable = true;

  # The VS Code server bootstrap downloads with wget.
  environment.systemPackages = [ pkgs.wget ];
}
