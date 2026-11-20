# nixos

A git-based NixOS configuration for a Windows 11 workstation running [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) on WSL2.

The aim is a workstation that is declarative, reproducible and atomic: the same configuration deploys quickly to any Windows 11 machine with WSL2. [comin](https://github.com/nlewo/comin) keeps each machine in sync with this repository, and a bad change can be rolled back to the previous generation.

## Status

Early stage. The repository holds the project structure and research. The flake and the installation guide come next.

## Getting started

Prerequisite: Windows 11 with WSL2 working. Setting up the Windows side is out of scope.

1. **Install NixOS-WSL** by following the official [installation guide](https://nix-community.github.io/NixOS-WSL/install.html).
2. **Apply this configuration.** The how-to will live in [`docs/`](docs/README.md) once the bootstrap path is decided. Research is in [`specs/projects/`](specs/projects/README.md).
3. **Stay in sync.** Once comin is enabled, the machine pulls and applies changes pushed to this repository.

## Repository layout

| Path | Contents |
|---|---|
| [`docs/`](docs/README.md) | User documentation: how-tos, tutorials, guides, checklists |
| [`specs/adr/`](specs/adr/README.md) | Architecture Decision Records |
| [`specs/projects/`](specs/projects/README.md) | Specifications and research notes |
| [`specs/intents/`](specs/intents/README.md) | Free-form ideas, before they become specs |
| [`specs/tasks/`](specs/tasks/README.md) | Large work broken down into ordered tasks |
