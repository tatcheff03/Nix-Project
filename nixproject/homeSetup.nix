{ config, lib, pkgs, ... }:

with lib;
with lib.types;

let
  # всички файловe зададени от потребителя в homeFiles
  cfg = config.homeFiles;

  # Функция: символна връзка + chmod
  generateLink = name: file:
    let
      # извлича се userName 
      uname = config.userName or "unknown";

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
    #  Задава се за кой потребител е този setup
    userName = mkOption {
      type = str;
      description = "Username for whom the home files are being setup.";
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

  #  Какво да се изпълни при активация на потребителя
  config = {
    system.userActivationScripts."setupHome_${config.userName}" = {
      text = ''
        echo "Creating of files in \$HOME"
        ${concatStringsSep "\n" (mapAttrsToList generateLink cfg)}
        echo "Done"
      '';
      deps = [];
    };
  };
}

