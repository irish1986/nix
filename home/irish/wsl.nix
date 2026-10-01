# WSL-only glue, imported by WSL hosts. The Windows PATH is off (see
# modules/nixos/wsl), so the Windows tools in use get small wrappers. They are
# scripts rather than aliases so git (core.editor = code) and other non-shell
# callers find them too.
{ pkgs, ... }:
let
  windows = "/mnt/c/Windows";
  wrap = name: target: pkgs.writeShellScriptBin name ''exec "${target}" "$@"'';

  # Clipboard tool for Neovim and anything that needs Unicode-safe copy and
  # paste. Not in nixpkgs; it is a Windows .exe run through WSL interop.
  win32yank = pkgs.fetchzip {
    url = "https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip";
    hash = "sha256-4ivE1cYZhYs4ibx5oiYMOhbse9bdOomk7RjgdVl5lD0=";
    stripRoot = false;
  };
in
{
  home.packages = [
    (wrap "code" "/mnt/c/Program Files/Microsoft VS Code/bin/code")
    (wrap "explorer" "${windows}/explorer.exe")
    (wrap "powershell" "${windows}/System32/WindowsPowerShell/v1.0/powershell.exe")
    (wrap "clip" "${windows}/System32/clip.exe")
    (wrap "win32yank" "${win32yank}/win32yank.exe")
    (pkgs.writeShellScriptBin "pbcopy" ''exec "${windows}/System32/clip.exe"'')
    (pkgs.writeShellScriptBin "pbpaste" ''exec "${windows}/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -Command Get-Clipboard'')
  ];

  # Opens links in the Windows default browser.
  home.sessionVariables.BROWSER = "${windows}/explorer.exe";
}
