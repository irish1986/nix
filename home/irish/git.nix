# Ported from the Ubuntu ~/.gitconfig, including SSH commit signing.
{ config, ... }:
let
  email = "simon.harvey.86@gmail.com";
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGtogx97FnhfW2KgyDQnQu15yl1L6CbCP7r0jmnchOZ";
in
{
  programs.git = {
    enable = true;

    ignores = [
      ".env"
      ".wip/"
      ".worktree/"
    ];

    settings = {
      user = {
        name = "Simon Harvey";
        inherit email;
        signingkey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      };
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
      commit = {
        gpgsign = true;
        verbose = true;
      };
      tag = {
        gpgsign = true;
        sort = "version:refname";
      };

      advice.diverging = false;
      branch.sort = "-committerdate";
      color.ui = "auto";
      column.ui = "auto";
      core = {
        autocrlf = false;
        editor = "code --wait";
      };
      diff = {
        algorithm = "histogram";
        colorMoved = "zebra";
      };
      fetch = {
        all = true;
        prune = true;
        pruneTags = true;
        writeCommitGraph = true;
      };
      help.autocorrect = "prompt";
      init.defaultBranch = "main";
      log.abbrevCommit = true;
      pull.rebase = true;
      push = {
        autoSetupRemote = true;
        default = "simple";
        followTags = true;
      };
      rebase.autoStash = true;
      rerere = {
        autoupdate = true;
        enabled = true;
      };
      status.short = true;
    };
  };

  # Lets `git log --show-signature` verify your own signatures.
  home.file.".ssh/allowed_signers".text = ''
    ${email} ${signingKey}
  '';
}
