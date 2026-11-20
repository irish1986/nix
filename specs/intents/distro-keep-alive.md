# Keep the NixOS distro alive for comin

Parked during the xsbug-1 wayfinder charting (2026-11-19).

comin only polls while the distro runs. WSL stops idle distros after `instanceIdleTimeout` (15 s) and the VM after `vmIdleTimeout` (60 s), and systemd services don't keep them alive ([research §4](../projects/research-nixos-wsl-comin-bootstrap.md#wsl2-specific-concerns)). Options: `instanceIdleTimeout=-1` in `.wslconfig` (recorded in `hosts/<name>/wslconfig`), or a Windows logon task that starts the distro. Both are Windows-side.
