{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      # Конфигурации на потребители
      userConfigs = {
        testuser = {
          homeFiles.".bashrc" = {
            text = ''
              export PATH=$PATH:$HOME/mybin
              echo "Hello from testuser!"
            '';
            mode = "600";
          };

          homeFiles.".vimrc" = {
            text = "set number\nsyntax on";
            mode = "644";
          };

          homeFiles."my_script.sh" = {
            source = ./my_script.sh;
            mode = "755";
          };
	
	homeFiles.".my_aliases" = {
  	source = ./my_aliases;
  	mode = "644";
	};
        };

        john = {
          homeFiles.".bashrc" = {
            text = ''
              export PATH=$PATH:$HOME/mybin
              echo "Hey John!"
            '';
            mode = "600";
          };

          homeFiles."my_script.sh" = {
            source = ./my_script.sh;
            mode = "755";
          };
        };
      };

    in {
      # За import в други системи
      nixosModules = {
        homeSetup = ./homeSetup.nix;
        systemExtras = ./systemExtras.nix;
      };

      # Конфигурация на VM
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.systemExtras
          self.nixosModules.homeSetup
          {
            # Подаване на потребители и техните homeFiles
            homeSetups = {
              john = {
                userName = "john";
                homeFiles = userConfigs.john.homeFiles;
              };
              testuser = {
                userName = "testuser";
                homeFiles = userConfigs.testuser.homeFiles;
              };
            };

            # Дефиниране на потребители
            users.users.testuser = {
              isNormalUser = true;
              initialPassword = "test";
              extraGroups = [ "wheel" ];
              packages = [ pkgs.vim ];
            };

            users.users.john = {
              isNormalUser = true;
              initialPassword = "john1";
              extraGroups = [ "wheel" ];
            };

            # системната версия
            system.stateVersion = "24.11";
          }
        ];
      };

      # Дефиниции на допълнителни пакети (напр. nix run .#activate-testuser)
      packages.${system} = {
        activate-testuser = pkgs.writeShellScriptBin "activate-home-testuser" ''
          echo "Setting up home for testuser..."
          ln -sf ${userConfigs.testuser.homeFiles."my_script.sh".source} "$HOME/my_script.sh"
          chmod ${userConfigs.testuser.homeFiles."my_script.sh".mode} "$HOME/my_script.sh"
          echo "Done."
        '';

        activate-john = pkgs.writeShellScriptBin "activate-home-john" ''
          echo "Setting up home for john..."
          ln -sf ${userConfigs.john.homeFiles."my_script.sh".source} "$HOME/my_script.sh"
          chmod ${userConfigs.john.homeFiles."my_script.sh".mode} "$HOME/my_script.sh"
          echo "Done."
        '';

        default = pkgs.writeShellScriptBin "noop" ''
          echo "Use: nix build .#nixosConfigurations.vm.config.system.build.vm"
        '';
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/noop";
      };
    };
}

