# Builds one Host. Everything every Host needs is added here, so host files
# stay short and no Host can forget the Base Role (ADR 0005).
{ inputs }:

# name:       the Host's name; also its hostname and its flake entry.
# hostModule: the Host's own file, hosts/<name>/default.nix.
name: hostModule:

inputs.nixpkgs.lib.nixosSystem {
  # Makes `inputs` available to every module, e.g. so the wsl Role can import
  # the NixOS-WSL module.
  specialArgs = { inherit inputs; };

  modules = [
    { networking.hostName = name; }
    inputs.home-manager.nixosModules.home-manager
    inputs.comin.nixosModules.comin # imported here, enabled in the Base Role later
    ../modules/roles/base.nix
    hostModule
  ];
}
