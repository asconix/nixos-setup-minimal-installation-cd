{ config, lib, pkgs, ... }: {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];
  
  environment.systemPackages = with pkgs; [ 
    dialog
  ];

  # Enable the OpenSSH daemon
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];

  users.users.root = {
    password = "changeme";
  };
}

