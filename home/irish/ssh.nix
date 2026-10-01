# Ported from the Ubuntu ~/.ssh/config. The private key itself is copied in by
# hand (see the README) and never committed. Keys are OpenSSH directive names.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ssh = "${config.home.homeDirectory}/.ssh";
  lan = hostName: user: {
    HostName = hostName;
    User = user;
    Port = 22;
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        KexAlgorithms = "curve25519-sha256@libssh.org,curve25519-sha256,diffie-hellman-group-exchange-sha256";
        Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr";
        MACs = "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com";
        HostKeyAlgorithms = "ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256";
        StrictHostKeyChecking = "ask";
        HashKnownHosts = true;
        VerifyHostKeyDNS = "ask";
        UpdateHostKeys = true;
        PubkeyAuthentication = true;
        IdentitiesOnly = true;
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AddKeysToAgent = true;
        ForwardAgent = false;
        ForwardX11 = false;
        ForwardX11Trusted = false;
        PermitLocalCommand = false;
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        Compression = false;
        ControlMaster = "auto";
        ControlPersist = "10m";
        IdentityFile = "${ssh}/id_ed25519";
        ControlPath = "${ssh}/sockets/%C";
      };

      edge = lan "192.168.1.253" "groot";
      rpi3-1 = lan "192.168.1.5" "groot";
      rpi4-1 = lan "192.168.1.7" "groot";
      rpi5-1 = lan "192.168.1.6" "groot";
      micro-bug = lan "192.168.10.75" "irish";
    };
  };

  # ControlPath needs the directory to exist; ssh will not create it.
  home.file.".ssh/sockets/.keep".text = "";

  # The Linux agent, as on Ubuntu. On a Mac the system agent is used instead.
  services.ssh-agent.enable = lib.mkIf pkgs.stdenv.isLinux true;
}
