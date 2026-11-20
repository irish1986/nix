# NixOS workstation configuration

A git repository that declares every NixOS machine the user runs, so each one can be rebuilt identically and kept in sync from git.

## Language

**Host**:
One NixOS installation that this repository configures, known by its own unique hostname. Two laptops with the same setup are two Hosts, and so are two NixOS distros on the same laptop.
_Avoid_: machine, system, box, configuration, laptop (a laptop may hold several Hosts)

**Home Host**:
A Host on one of the user's own computers. It is named after its Windows computer name.
_Avoid_: personal host, private host

**Work Host**:
A Host on a work computer managed by the user's employer. It has a neutral name and nothing that identifies the workplace appears in plain text in the repository.
_Avoid_: office host, corporate host, managed host

### Composition

**Feature**:
One self-contained concern of a Host's setup, such as git, WSL integration or a container runtime. Including a Feature turns it on.
_Avoid_: module (too generic), component, plugin

**Role**:
A named bundle of Features describing what kind of Host something is. A Host takes the Base Role, exactly one Platform Role, exactly one Kind Role, any Purpose Roles, and its own Features.
_Avoid_: profile, preset, template

**Base Role**:
The Role every Host takes, holding what no Host may go without.
_Avoid_: common, core, default

**Platform Role**:
The Role that says what a Host runs on, such as WSL.
_Avoid_: target, environment

**Kind Role**:
The Role that says whose environment a Host is: home or work. A Home Host takes the home Kind Role; a Work Host takes the work Kind Role.
_Avoid_: context, profile

**Purpose Role**:
A Role for a job that two or more Hosts do, such as development or GPU compute. A purpose done by only one Host stays as Features in that Host instead.
_Avoid_: use case, flavour

### People

**Person**:
A human whose identity (name, email) and personal setup (shell, git, editor) are declared once and can appear on several Hosts. An Account may override parts of the identity, such as a work email.
_Avoid_: user (ambiguous between Person and Account)

**Account**:
A login on one Host, belonging to one Person. The same Person may have Accounts with different names on different Hosts.
_Avoid_: user, username (when meaning the whole login)
