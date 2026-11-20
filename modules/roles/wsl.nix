# Platform Role: the Host runs as a WSL2 distro (ADR 0001).
{ inputs, ... }:
{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ../features/vscode-remote.nix
  ];

  wsl.enable = true;
}
