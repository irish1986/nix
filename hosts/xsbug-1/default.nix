# Host: xsbug-1, a Home Host on the Windows computer XSBUG-1.
# mkHost adds the Base Role and sets the hostname from the flake entry.
{ ... }:
{
  imports = [
    ../../modules/roles/wsl.nix # Platform Role
    ../../modules/roles/home.nix # Kind Role
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # The Account WSL logs into by default. Changing it needs `nixos-rebuild boot`
  # and a restart, never `switch` (NixOS-WSL docs: change-username).
  wsl.defaultUser = "irish";

  my.accounts.irish = {
    person = ../../people/simon;
    admin = true;
  };

  # The NixOS release this Host was first installed with. Never change it.
  system.stateVersion = "26.05";
}
