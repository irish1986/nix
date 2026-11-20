{
  description = "NixOS configuration for my Hosts (see specs/adr/0005-host-role-feature-layout.md)";

  inputs = {
    # Every Host uses the same stable nixpkgs (ADR 0005).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # NixOS-WSL release branch built against the same nixpkgs (ADR 0001).
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # home-manager runs as a NixOS module, so a system rebuild (or comin) also
    # deploys each Person's setup.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # comin, pinned to a tag. Its own nixpkgs input is unpinned upstream, so
    # `follows` is required (research note §4).
    comin = {
      url = "github:nlewo/comin/v0.14.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      mkHost = import ./lib/mkHost.nix { inherit inputs; };
    in
    {
      # One entry per Host. The name is the hostname and what comin matches on.
      nixosConfigurations = {
        xsbug-1 = mkHost "xsbug-1" ./hosts/xsbug-1;
      };
    };
}
