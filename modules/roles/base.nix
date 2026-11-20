# Base Role: what no Host may go without. mkHost adds it to every Host.
{ ... }:
{
  imports = [ ../accounts.nix ];

  # Flakes and the new `nix` command; the stock NixOS-WSL image has neither.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # comin is enabled here in the "Enable comin and watch a push arrive" ticket.
}
