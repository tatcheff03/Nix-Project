{ config, lib, pkgs, ... }:

with lib;
with lib.types;

let
  # Функция: символна връзка + chmod
  generateLink = uname: name: file:
    let
      # Ако има "text", създаваме нов файл с такова съдържание
      target =
        if file ? text then
          # генерирано съдържание със специфично име
          pkgs.writeText "homefile-${uname}-${baseNameOf name}" file.text

        # Ако имаме "source", използваме съществуващ файл
        else if file ? source then
          file.source

        # Ако липсват и двете –> грешка
        else
          throw "homeFiles.${name} трябва да има text или source.";

      # зададен режим (например '600'), добавяме chmod 
      modePart =
        if file ? mode then "\nchmod ${file.mode} \"$HOME/${name}\""
        else "";
    in

    # Команди:
    # 1. echo → логване в .home-setup.log
    # 2. ln -sf ... → символна връзка
    # 3. chmod ...  → по избор, chmod
    ''
      echo "[homeSetup] Linking $HOME/${name} -> ${target}" >> $HOME/.home-setup.log
      ln -sf ${target} "$HOME/${name}"${modePart}
    '';
   in

	{
 	options = {
    	homeSetups = mkOption {
	type = attrsOf (submodule ({ name, ... }: {
        options = {
          #  Задава се за кой потребител е този setup
          userName = mkOption {
            type = str;
            description = "Username for whom the home files are being setup.";
            default = name;
          };

          #  Списък от файлове за добавяне в $HOME
          homeFiles = mkOption {
            type = attrsOf (submodule {
              options = {
                #  Подаване на съдържание директно
                text = mkOption {
                  type = nullOr str;
                  default = null;
                  description = "Content of the file.";
                };

                #  Използване на съществуващ файл
                source = mkOption {
                type = nullOr path;
		default = null;
                description = "Path to an existing file.";
                };

                #  Права върху файла (напр. '600')
                mode = mkOption {
                  type = str;
                  default = "644";
                  description = "Rights for the file (e.g., '600', '644', '755').";
                };
              };
            });

            default = {};
            description = "Map of files to link into the user's $HOME.";
          };
        };
      }));
    };
  };

  #  Какво да се изпълни при активация на потребителя
  config = {
    system.userActivationScripts = 
    lib.flip lib.mapAttrs' config.homeSetups (name: { userName, homeFiles }:
    lib.nameValuePair "setupHome_${userName}" {
      text = ''
        echo "Creating of files in $HOME for ${userName}"
        if [ $USER = ${userName} ]; then
          ${concatStringsSep "\n" (mapAttrsToList (generateLink userName) homeFiles)}
        fi
        echo "Done for ${userName}"
      '';
      deps = [];
    });
  };
}
