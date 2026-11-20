# Enable comin and watch a push arrive

Type: task (HITL)
Status: open
Blocked by: 06

## Question

Turn on comin in the Base Role, pointed at `https://github.com/irish1986/nix.git`, with the exporter bound to `127.0.0.1` ([ADR 0003](../../../adr/0003-comin-for-gitops-pending-wsl-restart-test.md) settings). Apply that once by hand. After that, push a visible change (e.g. a package or a shell alias) and watch it arrive without running `nixos-rebuild`.

The agent writes `docs/how-to/gitops-with-comin.md`, covering `comin status`, `journalctl -u comin` and what a failed deployment looks like.

**Done when:** a pushed commit is applied on `xsbug-1` within about 2 minutes with a terminal open, and `comin status` shows that commit.
