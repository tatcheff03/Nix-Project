{ config, lib, pkgs, ... }:

with lib;
with lib.types;

{
   #homeSetups във флейка
  options.homeSetups = mkOption {
    type = attrsOf (submodule ({ name, ... }: 
    let
    userName=name;

    in {
      options = {
        userName = mkOption {
          type = str; default = name;
          description = "Име на потребителя";
        };
	#какви файлове се подават
        homeFiles = mkOption {
          type = attrsOf (submodule ({config, name, ... }: {
            options = {
              text   = mkOption { type = nullOr str;  default = null; };
              source = mkOption { type = nullOr path; default = lib.mapNullable (text:
                pkgs.runCommand "homefile-${userName}-${lib.escapeShellArg name}" { } ''
                  echo ${lib.escapeShellArg text} > $out
                  chmod ${config.mode} $out
                ''
              ) config.text; };
              mode   = mkOption { type = str;         default = "644"; };
            };
          }));
          default = {};
          description = "Файлове, които се добавят в \$HOME директорията";
        };
      };
    }));
  };

  options.generatedSetupScripts = mkOption {
    type = attrsOf package;
    readOnly = true;
    description = "Генерирани скриптове за настройка на home директорията";
  };

  config.generatedSetupScripts = lib.mapAttrs (user: cfg:
    pkgs.writeShellScriptBin "setupHome_${user}" ''
      #!/usr/bin/env bash
      # TODO: problems?
      # set -euo pipefail
     
       if [ "$(id -u -n)" == ${user} ]; then
        USER_HOME="/home/${user}"
        ${lib.pipe cfg.homeFiles [
          (lib.mapAttrsToList (filePath: { mode, source, ... }: ''
            # Linking ${filePath}
            link=~${user}/${lib.escapeShellArg filePath}
            if [ -L $link ]; then
              # It's a symlink – remove it
              unlink $link
              ln -s "${source}" $link
            elif [ ! -e $link ]; then
              # Doesn't exist at all – just create the symlink
              mkdir -p "$(dirname $link)"
              ln -s "${source}" $link
            else
              # Exists and is not a symlink – don't touch
              echo "Not a symlink, not touching: $link" >&2
              exit 1
            fi
          ''))
          (lib.concatStringsSep "\n")
        ]}

        # Слагаме флаг, че setup е приключил
        touch "$USER_HOME/.home-setup.done"
      fi
    ''
  ) config.homeSetups;

    config.environment.systemPackages =
    builtins.attrValues config.generatedSetupScripts;



  # Активираме скрипта 
  config.system.userActivationScripts =
    lib.mapAttrs (_: pkg: {
      text = ''
        exec ${lib.getExe pkg}
      '';
      deps = [];
    }) config.generatedSetupScripts;
}

