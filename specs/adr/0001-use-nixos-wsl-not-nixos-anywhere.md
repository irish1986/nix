# 0001. Use NixOS-WSL as the base; do not use nixos-anywhere

- Status: Accepted
- Date: 2026-11-19

## Context

The workstation runs NixOS as a WSL2 distro on Windows 11. We need a supported way to run NixOS under WSL2 and a way to get it onto each machine.

nixos-anywhere was considered as the bootstrap tool. It works by switching the target into an installer kernel with kexec, wiping and partitioning the disk with disko, running `nixos-install` and rebooting. A WSL2 distro has none of the things that pipeline needs:

- It has no kernel or bootloader of its own. Every distro shares one Microsoft-managed VM kernel, and NixOS-WSL disables the NixOS kernel, initrd and bootloader.
- Its root filesystem is a VHDX that `wsl.exe` manages, not a disk to partition.
- Distros are created from Windows, with `wsl --install --from-file` or `wsl --import`.

nixos-anywhere itself detects WSL as a container and warns that kexec will likely not work. Its docs list WSL2 only as a machine to deploy *from*, not one to install *onto*.

NixOS-WSL (nix-community) is the maintained project for running NixOS under WSL2. It ships a NixOS module (`wsl.*` options), release images (`nixos.wsl`) and a builder for custom images.

Evidence: [research note §1–3](../projects/research-nixos-wsl-comin-bootstrap.md#3-nixos-anywhere-and-wsl2).

## Decision

- Use NixOS-WSL as the base: `nixos-wsl.nixosModules.default` with `wsl.enable = true`.
- Track stable releases: nixpkgs `nixos-26.05` and NixOS-WSL `release-26.05`, built against the same nixpkgs and both pinned in `flake.lock`.
- Do not use nixos-anywhere to install or bootstrap WSL machines. ADR 0002 sets the bootstrap path.

## Consequences

- NixOS kernel options (`boot.kernelPackages`, `boot.kernelParams`, kernel modules) do not apply. The kernel is Microsoft's, and only `.wslconfig` on the Windows side can change it, if the work IT policy allows.
- There is no boot menu for rollbacks. Rolling back means `nixos-rebuild switch --rollback` from inside the distro, or the NixOS-WSL recovery shell if the distro won't start.
- Some NixOS behaviour is changed or off under WSL: the NixOS firewall unit is disabled, Windows handles DHCP, WSL generates `/etc/resolv.conf` and `/etc/hosts` by default, and udev is off by default. Configuration in this repo must not rely on them.
- Moving to a new NixOS release means bumping both inputs together once NixOS-WSL cuts the matching `release-*` branch.
- nixos-anywhere stays usable later for real servers or VMs, run from this WSL workstation.
