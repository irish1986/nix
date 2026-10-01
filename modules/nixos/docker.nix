# Docker engine inside NixOS. Leave Docker Desktop's WSL integration off for
# this distro so two daemons never fight over /var/run/docker.sock.
{ username, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  users.users.${username}.extraGroups = [ "docker" ];
}
