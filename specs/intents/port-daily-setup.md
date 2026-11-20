# Port the daily Ubuntu setup to NixOS

Parked during the xsbug-1 wayfinder charting (2026-11-19).

Once `xsbug-1` syncs from git, bring over what the Ubuntu workbench has today: dev toolchains, CLI tools, editor config, GUI apps through WSLg. Each one is a small commit pushed and watched arriving. The end state: `xsbug-1` can replace Ubuntu as the daily distro.

Already known from "Decide the minimal Person setup": the oh-my-zsh `vscode`, `you-should-use` and `command-not-found` plugins (the last works differently on NixOS; look at `nix-index`).
