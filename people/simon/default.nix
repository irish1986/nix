# Person: Simon. A home-manager module, so it holds identity and personal
# setup, never a username (the Account on each Host supplies that).
# Scope decided in specs/tasks/xsbug-1-gitops/issues/01-minimal-person-setup.md.
{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "history"
      ];
    };

    # powerlevel10k prompt, configured by the same .p10k.zsh as on Ubuntu.
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initContent = ''
      source ${./p10k.zsh}
    '';
  };

  # Public repo: the GitHub noreply address, never the personal email.
  programs.git = {
    enable = true;
    settings.user = {
      name = "Simon Harvey";
      email = "13018674+irish1986@users.noreply.github.com";
    };
  };

  # vim is $EDITOR: it works even when VS Code or Windows interop does not.
  programs.vim = {
    enable = true;
    defaultEditor = true;
  };
}
