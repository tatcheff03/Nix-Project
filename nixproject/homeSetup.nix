{ config, lib, pkgs, ... }:

with lib;
with lib.types;

let
  #  Функция за линкване на файл в home директорията 
  generateLink = uname: fileName: file:
    let
      homePath = "/home/${uname}/${fileName}";  # Къде ще бъде линкнат 

      #  Избираме източника на файла: текст или път до друг файл
      target =
        if file?text && file.text != null then
          pkgs.writeText "homefile-${uname}-${baseNameOf fileName}" file.text
        else if file?source && file.source != null then
          file.source
        else
          throw "homeFiles.${fileName} трябва да има text или source.";

      #  Проверка дали файлът вече е в /nix/store
      isStorePath = lib.hasPrefix "/nix/store" (toString target);

      #  Ако не е от /nix/store и има зададен режим, слагаме chmod
      modeLine = if file?mode && !isStorePath then
        "chmod ${file.mode} \"${homePath}\""
      else
        "";
    in
      # shell код за логване, линкване и задаване на права
      ''
        echo "[homeSetup] Linking ${homePath} -> ${target}" >> /home/${uname}/.home-setup.log
        ln -sf ${target} "${homePath}"
        ${modeLine}
      '';
in {
  options = {
    # нова NixOS опция `homeSetups`
    homeSetups = mkOption {
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          userName = mkOption {
            type = str;
            description = "Името на потребителя";
            default = name;
          };
          homeFiles = mkOption {
            type = attrsOf (submodule {
              options = {
                text   = mkOption { type = nullOr str; default = null; };
                source = mkOption { type = nullOr path; default = null; };
                mode   = mkOption { type = str; default = "644"; };
              };
            });
            default = {};
            description = "Файлове, които се добавят в $HOME на потребителя";
          };
        };
      }));
    };
  
  
    generatedSetupScripts = mkOption {
    type = attrsOf package;
    readOnly = true;
    description = "Generated setup scripts for each user.";
  };
};


  config = {
    # Скриптове, достъпни през vmSystem.config.generatedSetupScripts
    generatedSetupScripts = lib.mapAttrs (user: value:
      pkgs.writeShellScriptBin "setupHome_${user}" ''
        set -e
        mkdir -p /home/${user}
        touch /home/${user}/.home-setup.log
        echo "[homeSetup] Running for ${user}" >> /home/${user}/.home-setup.log
        ${lib.concatStringsSep "\n"
          (lib.mapAttrsToList (name: file: generateLink user name file) value.homeFiles)}
        echo "[homeSetup] Done for ${user}" >> /home/${user}/.home-setup.log
      ''
    ) config.homeSetups;

    # Скриптове, които се изпълняват автоматично при login
    system.userActivationScripts =
      lib.flip lib.mapAttrs' config.homeSetups
        (user: { userName, homeFiles }:
          lib.nameValuePair ("setupHome_${userName}") {
            text = ''
              set -e
              echo "[homeSetup] Running for ${userName}" >> /home/${userName}/.home-setup.log
              ${concatStringsSep "\n"
                (mapAttrsToList (name: value: generateLink userName name value) homeFiles)}
              echo "[homeSetup] Done for ${userName}" >> /home/${userName}/.home-setup.log
            '';
            deps = [];
          });
  };
}

