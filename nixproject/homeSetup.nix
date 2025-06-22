		{ config, lib, pkgs, ... }:

		with lib;
		with lib.types;

		let
		  # Функция: символна връзка + chmod
		  generateLink = uname: fileName: file:
		    let
		      homePath = "/home/${uname}/${fileName}";

		      # Определяне на източника: текст или съществуващ файл
		      target =
			if file?text && file.text != null then
			  pkgs.writeText "homefile-${uname}-${baseNameOf fileName}" file.text
			else if file?source && file.source != null then
			  file.source
			else
			  throw "homeFiles.${fileName} трябва да има text или source.";

		      isStorePath = lib.hasPrefix "/nix/store" (toString target);
		      modeLine = if file?mode && !isStorePath then
			"chmod ${file.mode} \"${homePath}\""
		      else
			"";
		    in
		      ''
			echo "[homeSetup] Linking ${homePath} -> ${target}" >> /home/${uname}/.home-setup.log
			ln -sf ${target} "${homePath}"
			${modeLine}
		      '';

		in
		{
		  options.homeSetups = mkOption {
		    type = attrsOf (submodule ({ name, ... }: {
		      options = {
			# Параметри за всеки потребител
			userName = mkOption {
			  type        = str;
			  description = "Username for whom the home files are being setup.";
			  default     = name;
			};
			homeFiles = mkOption {
			  type = attrsOf (submodule {
			    options = {
			      text   = mkOption { type = nullOr str; default = null; };
			      source = mkOption { type = nullOr path; default = null; };
			      mode   = mkOption { type = str;      default = "644"; };
			    };
			  });
			  default     = {};
			  description = "Map of files to link into the user's $HOME.";
			};
		      };
		    }));
		  };

		  config.system.userActivationScripts =
		    lib.flip lib.mapAttrs' config.homeSetups (user: { userName, homeFiles }: lib.nameValuePair ("setupHome_${userName}") {
		      text = ''
			set -e
			echo "[homeSetup] Running for ${userName}" >> /home/${userName}/.home-setup.log

			  # Линкваме всички файлове, включително .bashrc
			 ${concatStringsSep "\n"
		  	(mapAttrsToList
		    	(name: value:
		      	generateLink userName name value)
		    	homeFiles)
			}

			echo "[homeSetup] Done for ${userName}" >> /home/${userName}/.home-setup.log
		      '';
		      deps = [];
		    });

		}
