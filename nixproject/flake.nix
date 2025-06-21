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

      # импортиране на homeSetup модула
      homeSetupTestUser = import ./homeSetup.nix {
        config = {
          userName = "testuser";
          homeFiles = userConfigs.testuser.homeFiles;
        };
        inherit lib pkgs;
      };

      homeSetupJohn = import ./homeSetup.nix {
        config = {
          userName = "john";
          homeFiles = userConfigs.john.homeFiles;
        };
        inherit lib pkgs;
      };
    in
    {
      # при nix run .#activate
      packages.${system}.activate =
        pkgs.writeShellScriptBin "activate-home"
          homeSetupTestUser.config.system.userActivationScripts.setupHome.text;

      # при nix run .#
      apps.${system}.default = {
        type = "app";
        program =
          "${pkgs.writeShellScriptBin "activate-home" homeSetupTestUser.config.system.userActivationScripts.setupHome.text}/bin/activate-home";
      };

      #  За импорт в други проекти (напр. модул в NixOS)
      nixosModules = {
        homeSetup = ./homeSetup.nix;
        systemExtras = ./systemExtras.nix;
      };

      # Конфигурация на VM
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          #  Глобални неща
          self.nixosModules.systemExtras

          #  Потребители  
          {
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

            # изпълнява setup скрипта за всеки user
            system.userActivationScripts = {
              setupHome_testuser.text = homeSetupTestUser.config.system.userActivationScripts."setupHome_testuser".text;
              setupHome_john.text = homeSetupJohn.config.system.userActivationScripts."setupHome_john".text;
            };

            # (декларация на съвместимост)
            system.stateVersion = "24.11";
          }
        ];
      };
    };
}

