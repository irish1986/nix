# NixOS-WSL on bigbug, next to the Ubuntu distro. Only host facts live here.
{ hostname, username, ... }:
{
  imports = [
    ../../modules/nixos/common
    ../../modules/nixos/wsl
    ../../modules/nixos/docker.nix
  ];

  networking.hostName = hostname;
  time.timeZone = "America/Toronto";

  # The release first installed. Never bump it, even after upgrading NixOS.
  system.stateVersion = "26.05";

  home-manager.users.${username}.imports = [ ../../home/${username}/wsl.nix ];
}
