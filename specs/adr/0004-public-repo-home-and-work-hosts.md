# 0004. Public repository, with Home Hosts and Work Hosts kept apart

- Status: Proposed
- Date: 2026-11-19

## Context

comin pulls each Host's configuration from a git remote, so the repository must live somewhere every Host can reach. It will configure two kinds of Host (see [GLOSSARY](../GLOSSARY.md)):

- **Home Hosts** on the user's own computers.
- **Work Hosts** on work computers managed by the user's employer.

Work Hosts need workplace-specific settings: a corporate root CA, a proxy, internal DNS domains and a work git identity. These are needed at build time, so encrypted secrets (sops-nix, agenix), which only decrypt at activation, cannot carry them ([research note §8](../projects/research-nixos-wsl-comin-bootstrap.md#8-addendum-2026-11-19-work-specific-settings-in-a-public-repo)).

Options considered:

- **Private repository.** Anything can be committed, but every Host needs a read-only credential before comin can fetch.
- **Public repository.** comin needs no credential and the work can be shared, but nothing identifying the workplace or its computers may be committed.
- **Public and private repositories from the start.** The cleanest separation, but two repositories and two locks to keep in step before any Work Host exists.

## Decision

- The repository is **public**.
- **Home Hosts** are named after their Windows computer name in lowercase, e.g. `xsbug-1`.
- **Work Hosts** get neutral names, `wsl-work-<n>`, never the work computer's own name or asset tag.
- Nothing that identifies the workplace is committed in plain text: not its name, CA, proxy, internal domains or work identity. Docs and specs refer to it only as "work".
- Settings specific to Work Hosts are designed when the first Work Host is added. The candidate is a private flake that takes this one as an input and defines the Work Hosts, with comin on those Hosts pointed at it ([intent](../intents/work-host-settings.md)).

## Consequences

- Home Hosts can bootstrap comin with no credential at all, which removes one manual step from ADR 0002's bootstrap.
- Publishing cannot be undone. Anything ever committed, including in history before the first push, must be checked against the rule above before the first push.
- Work Hosts will depend on a second, private repository, and public changes will reach them only after its `flake.lock` is bumped.
- Commit signature verification in comin (ADR 0003) matters more on a public repository, because it guards against a compromised remote.
