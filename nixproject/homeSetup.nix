{ config, lib, pkgs, ... }:

with lib;
with lib.types;

let
  # всички файловe зададени от потребителя в homeFiles
  cfg = config.homeFiles;

  # Функция символна връзка + chmod 
  generateLink = name: file:
    let
      # Ако има "text", създаваме нов файл с такова съдържание
      target =
        if file ? text then
          pkgs.writeText "homefile-${baseNameOf name}" file.text

        # Ако имаме "source", използваме съществ. файл
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
    # 1. ln -sf ... →  символна връзка
    # 2. chmod ...  → по избор, chmod
    ''
      ln -sf ${target} "$HOME/${name}"${modePart}
    '';
in

{
  # какви настройки (options) може да се подават
  options.homeFiles = mkOption {
    #подават се списък от файлове с text/source/mode
    type = attrsOf (submodule {
      options = {
        # подава се "text", генерира се съдържанието
        text = mkOption {
          type = nullOr str;
          default = null;
          description = "Content of file.";
        };

        # подава се "source", файлът сочи към друг файл
        source = mkOption {
          type = nullOr path;
          default = null;
          description = "Path to existing file.";
        };

        # Ако подаде "mode" -> chmod (например '600')
        mode = mkOption {
          type =  str;
          default = "644";
          description = "Rights for file (ex. '600', '644','755').";
        };
      };
    });

    # По подразбиране няма файлове
    default = {};
    description = "Файлове -> добавят в $HOME като връзки.";
  };

  # какво да се изпълни при активация
  config = {
    system.userActivationScripts.setupHome = {
      text = ''
        echo "Creating of files in \$HOME"
        ${concatStringsSep "\n" (mapAttrsToList generateLink cfg)}
        echo "Done"
      '';
      deps = [];
    };
  };
}

