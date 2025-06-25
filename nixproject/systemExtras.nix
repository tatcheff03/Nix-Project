{ config, pkgs, lib, ... }:

{
  config = {

    #  Mate  + lightdm за логин
    services.xserver = {
      enable = true;
      desktopManager.mate.enable = true;
      displayManager.lightdm.enable = true;
    };

    #  DHCP за интернет
    networking.useDHCP = true;

    #  Пакети: mate-terminal, firefox + global-script
    environment.systemPackages = with pkgs; [
      mate.mate-terminal
	brave
      (pkgs.writeShellScriptBin "global-script.sh" ''
        #!/bin/bash
        echo " Hello from global script!"
      '')
    ];

    # съобщение при login
    programs.bash.loginShellInit = ''
      echo " Hello, $USER! Welcome to your test VM!"
      global-script.sh
    '';
  };
}

