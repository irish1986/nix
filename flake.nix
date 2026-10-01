{
  description = "irish1986 — NixOS on WSL (later bare metal and nix-darwin) with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Track the release branch, not the 2605.7.2 tag: only the branch has the
    # /bin/true fix that current WSL needs (NixOS-WSL #1100).
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      mylib = import ./lib { inherit inputs self; };
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      overlays = import ./overlays { inherit inputs; };

      nixosConfigurations = {
        bigbug-nixos = mylib.mkNixos {
          hostname = "bigbug-nixos";
          username = "irish";
        };
      };

      formatter.${system} = pkgs.nixfmt-tree;

      # `nix flake check` builds the whole system, so CI catches anything that
      # would fail on `nixos-rebuild`.
      checks.${system}.bigbug-nixos = self.nixosConfigurations.bigbug-nixos.config.system.build.toplevel;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt-tree
          nil
          nh
          statix
          deadnix
        ];
      };
    };
}
