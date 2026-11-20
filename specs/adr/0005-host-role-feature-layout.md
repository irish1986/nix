# 0005. Layered Host, Role and Feature layout in a plain flake

- Status: Accepted
- Date: 2026-11-19

## Context

The repository will configure several Hosts: three Home Hosts that differ in WSL integrations and purpose, and Work Hosts later. Some setup is shared by all of them and some is unique to one. The goal is a layout that doesn't repeat itself (DRY) and stays easy to read while the user is learning NixOS. Terms are defined in the [GLOSSARY](../GLOSSARY.md).

Options considered for the flake's structure:

- A plain flake with a small `mkHost` helper.
- flake-parts.
- The dendritic pattern (flake-parts + import-tree).
- Snowfall lib.

Options considered for composition:

- Features bundled into Roles.
- Modules switched on by enable options (`my.<x>.enable`).
- Flat per-Host lists of Features.

## Decision

- **Plain flake.** `flake.nix` lists one `nixosConfigurations` entry per Host. `lib/mkHost.nix` builds each Host and always adds the Base Role, the home-manager NixOS module and the comin module.
- **One entry per Host.** A Host is one NixOS installation with a unique name; two distros on one laptop are two Hosts.
- **Features, imported to turn on.** A Feature is one concern per file under `modules/features/`; there are no enable flags.
- **Roles in layers.** Every Host takes:
  - the Base Role, added by `mkHost`;
  - exactly one Platform Role (`wsl`);
  - exactly one Kind Role (`home` or `work`);
  - any Purpose Roles, each created only once a second Host needs the same bundle;
  - its own Features in `hosts/<name>/default.nix`.
- **People and Accounts.** A Person's setup is one home-manager module under `people/<name>/` that never mentions a username. Each Host declares its Accounts under `my.accounts.<username>` and attaches a Person to each. home-manager stays a NixOS module, so comin deploys it with the system.
- **Own options under `my.*`.**
- **One nixpkgs for every Host.** All Hosts use `nixos-26.05`, with nixos-unstable available for individual packages only.
- **Windows-side config as reference.** Each Host may keep a copy of its Windows-side `.wslconfig` in `hosts/<name>/wslconfig`, applied by hand.

```
flake.nix  flake.lock
lib/mkHost.nix
modules/features/   modules/roles/{base,wsl,home}.nix
people/simon/
hosts/<name>/{default.nix,wslconfig}
```

## Consequences

- flake-parts can be adopted later without moving Features or Roles, because they stay plain NixOS modules.
- Turning off a Feature that a Role brings in needs `lib.mkForce`, since Features have no enable flags. If that keeps happening, it means the Role is too broad.
- Shared home-manager Features (`modules/home/`) are only extracted when a second Person appears.
- Adding a Host means a commit before bootstrapping it. git becomes the inventory of every Host.
