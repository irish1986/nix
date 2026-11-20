# comin commit signing

Parked during the xsbug-1 wayfinder charting (2026-11-19), to do right after `xsbug-1` first syncs from git.

The repository is public, so comin should only deploy commits the user has signed. Sign commits with an SSH key, commit an `allowed_signers` file holding public keys only, and set `services.comin.sshAllowedSignersPath`. comin checks only the tip commit ([ADR 0003](../adr/0003-comin-for-gitops-pending-wsl-restart-test.md), [research §6](../projects/research-nixos-wsl-comin-bootstrap.md#6-security-relevant-notes-appsec-lens)).
