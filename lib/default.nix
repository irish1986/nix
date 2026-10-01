{ inputs, self }:
{
  # One NixOS host: its hosts/<hostname> folder, plus Home Manager for one user
  # whose config lives in home/<username>.
  mkNixos =
    {
      hostname,
      username,
      system ? "x86_64-linux",
      extraModules ? [ ],
    }:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit
          inputs
          self
          hostname
          username
          ;
      };
      modules = [
        {
          nixpkgs = {
            hostPlatform = system;
            overlays = builtins.attrValues self.overlays;
            config.allowUnfree = true;
          };
        }
        ../hosts/${hostname}
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            # Existing dotfiles are renamed to *.hm-bak instead of aborting activation.
            backupFileExtension = "hm-bak";
            extraSpecialArgs = {
              inherit
                inputs
                self
                hostname
                username
                ;
            };
            users.${username} = ../home/${username};
          };
        }
      ]
      ++ extraModules;
    };
}
