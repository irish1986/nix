# The Accounts mechanism, part of the Base Role. A Host declares
#
#   my.accounts.<username> = { person = ../../people/<person>; admin = true; };
#
# and gets a login named <username> whose home is built from that Person's
# home-manager setup. The Person never mentions a username, so the same Person
# can have differently named Accounts on different Hosts (see specs/GLOSSARY.md).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.accounts;
in
{
  options.my.accounts = lib.mkOption {
    description = "Accounts on this Host, each attached to a Person.";
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          person = lib.mkOption {
            type = lib.types.path;
            description = "The Person's home-manager module, e.g. ../../people/simon.";
          };
          admin = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the Account may use sudo (member of wheel).";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg != { }) {
    # The login shell must also be enabled system-wide. zsh for every Account
    # for now, because the only Person uses it.
    programs.zsh.enable = true;

    # home-manager uses the system's nixpkgs and installs into the user profile.
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    users.users = lib.mapAttrs (_name: account: {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = lib.optional account.admin "wheel";
    }) cfg;

    home-manager.users = lib.mapAttrs (_name: account: {
      imports = [ account.person ];
      # Tied to the Host's first install, like system.stateVersion.
      home.stateVersion = config.system.stateVersion;
    }) cfg;
  };
}
