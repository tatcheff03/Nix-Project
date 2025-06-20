{ config, pkgs, lib, setupScript, ... }:

{
  config = {
    environment.systemPackages = [
	pkgs.vim
      (pkgs.writeShellScriptBin "global-script.sh" ''
        #!/bin/bash
        echo " Hello from global script!"
      '')
    ];

    programs.bash.loginShellInit = ''
      echo " Hello, $USER! Welcome to your test VM!"
      global-script.sh
      echo " Syncing home setup..."
      ${setupScript}/bin/activate-home
    '';
  };
}

