# Plain zsh: no framework or prompt theme yet. fzf, zoxide and direnv hook
# themselves in from default.nix.
{ config, ... }:
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    history = {
      size = 50000;
      save = 50000;
      path = "${config.xdg.dataHome}/zsh/history";
      ignoreDups = true;
      share = true;
    };
  };
}
