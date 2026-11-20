# Work Host settings (deferred)

Deferred during grill-me-docs-1 (2026-11-19) until the first Work Host is added.

The repository is public. Work Hosts need settings specific to the workplace (corporate root CA, proxy, internal DNS domains, possibly a work git identity), and these must not appear in plain text in a public repo. Encrypted secrets (sops-nix, agenix) cannot provide them, because they are needed at build time.

The candidate is an inverted flake: a private repository whose flake takes this public flake as an input and defines the Work Hosts, with comin on those Hosts pointed at the private repository.

Findings: [research note §8](../projects/research-nixos-wsl-comin-bootstrap.md#8-addendum-2026-11-19-work-specific-settings-in-a-public-repo).

To decide when the time comes:

- Inverted private flake, or a private input of this flake?
- Where the work `git` identity lives.
- Whether WSL `autoProxy` is enough for interactive shells, and how comin and nix-daemon get the proxy.
- How the comin credential for the private repo reaches a new Work Host at bootstrap.
