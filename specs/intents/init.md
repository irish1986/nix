# Project Init

The goal of this project is to help me build a `wsl2` NixOS configuration for my workstation.

I am an application security lead and I would like to level NixOS idempotency and atomic configuration to help me ensure my daily workstation is always working and running.  I have extensive experience with `ubuntu` but I wish to move toward `nixos`.

## Goal

I wish to build a git-based `nixos` configuration that I can improve and upgrade over time.  The goal is to be able to deploy quickly the same configuration on an Windows 11 machines that support `wsl2`.  The Windows configuration is out of scope assume everything works to get started installin `nixos`

## Git-Based

I would like to use `comin` (https://github.com/nlewo/comin) to help me sync my configuration with git configuration. My understanding is that nix-anywhere can be use to bootstrap the whole process.  This needs to be research for `wsl2` compatibility.

## Structure

This project structure goes as following:

- `docs/` is only for user documentation, how-to, tutorial, guides and checklist.  Do not include any spec or related, it is purely for project docs.
- `specs/` contains the `specs/adr/` dir for associated decision, `specs/projects/` for specs documentation, `specs/intents` is a free document where i write new idea and finally `specs/tasks/` is for breaking down large chunck of work.
- `README.md` must be a short getting start summary of the project

## Out of scope

As a starter the following item are out of scope:

- Any CI-CD pipeline and validation, these will come later
- Any tests or local 

## Limit

As part of this project these are your limits:

- Do not push any code to GitHub
- Do not execute any automated installation, rather provide me a guide of how-to (i am testing and learning the deployment mechanism)

## Reference

- https://github.com/nix-community/NixOS-WSL
- https://nix-community.github.io/NixOS-WSL/install.html
- https://medium.com/@piyushkumarsingh.nmims/nixos-on-wsl-the-best-of-both-worlds-bdcaba54ee58
- https://nixos.wiki/wiki/WSL
- https://www.reddit.com/r/NixOS/comments/1eguj7b/nisoswsl_is_awesome/
- https://nixos.org/download/
- https://dev.to/jajera/using-nix-on-windows-the-right-way-14ki
- https://andrewowen.net/blog/running-nixos-full-screen-on-wsl2/
- https://www.greghilston.com/post/nixos-on-wsl/
- https://news.ycombinator.com/item?id=40781473
- https://forrestjacobs.com/nixos-on-wsl/
- https://discourse.nixos.org/t/undesired-behavior-of-x11-apps-in-nixos-on-wsl/74553
