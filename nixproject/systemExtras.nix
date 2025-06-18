{ config, pkgs, lib, ... }:

{
  config = {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "global-script.sh" ''
        #!/bin/bash
        echo " Hello from global script!"
      '')
    ];

    programs.bash.loginShellInit = ''
      echo " Hello, $USER! Welcome to your test VM!"
      global-script.sh
    '';
  };
}

