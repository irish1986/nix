# Feature: VS Code on Windows can open folders in this distro (Remote-WSL).
# The VS Code server ships a Node binary built for ordinary Linux; nix-ld gives
# it the dynamic loader it expects. The server's installer downloads with wget.
# Source: NixOS-WSL docs/src/how-to/vscode.md.
{ pkgs, ... }:
{
  programs.nix-ld.enable = true;
  environment.systemPackages = [ pkgs.wget ];
}
