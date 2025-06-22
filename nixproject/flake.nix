# vim: set sw=2 expandtab:
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs   = import nixpkgs { inherit system; };
    lib    = pkgs.lib;

    # Конфигурации за всеки потребител и файловете му
    userConfigs = {
      testuser = {
        homeFiles = {
          ".bashrc" = {
            text = ''
              if [ ! -f "$HOME/.home-setup.done" ]; then
                /etc/profiles/per-user/$USER/bin/setupHome_$USER
                touch "$HOME/.home-setup.done"
              fi
              echo "Hello from testuser!"
            '';
            mode = "600";
          };
          ".vimrc" = { text = "set number\nsyntax on"; mode = "644"; };
          "my_script.sh" = { source = ./my_script.sh; mode = "755"; };
          ".my_aliases" = { source = ./my_aliases; mode = "644"; };
        };
      };

      john = {
        homeFiles = {
          ".bashrc" = {
            text = ''
              if [ ! -f "$HOME/.home-setup.done" ]; then
                /etc/profiles/per-user/$USER/bin/setupHome_$USER
                touch "$HOME/.home-setup.done"
              fi
              echo "Hey John!"
            '';
            mode = "600";
          };
          "my_script.sh" = { source = ./my_script.sh; mode = "755"; };
        };
      };
    };

    # Генериране на VM конфигурация
    vmSystem = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.systemExtras
        self.nixosModules.homeSetup
        {
          homeSetups = userConfigs;

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

          #  Копиране на файлове в /etc/home/... за достъп във VM
          virtualisation.vmVariant.environment.etc =
            lib.foldl'
              (acc: user:
                lib.foldl'
                  (acc2: fileName:
                    let
                      file = userConfigs.${user}.homeFiles.${fileName};
                      destPath = "home/${user}/${fileName}";
                      src = if file ? text
                        then pkgs.writeText "inline-${user}-${fileName}" file.text
                        else file.source;
                    in
                      acc2 // {
                        "${destPath}" = {
                          source = src;
                          mode = file.mode;
                        };
                      }
                  )
                  acc
                  (lib.attrNames userConfigs.${user}.homeFiles)
              )
              {}
              (lib.attrNames userConfigs);

          boot.loader.grub.devices = [ "/dev/sda" ];
          fileSystems."/" = {
            device = "/dev/sda1";
            fsType = "ext4";
          };

          system.stateVersion = "24.11";
        }
      ];
    };

  in {
    #  NixOS модули
    nixosModules = {
      systemExtras = ./systemExtras.nix;
      homeSetup    = ./homeSetup.nix;
    };

    # Конфигурация за VM
    nixosConfigurations.vm = vmSystem;

    #  Пакети (локално ползване)
    packages.${system} = {
      #  Скриптовете setupHome_* са експортирани от homeSetup.nix
      setupHome_testuser = vmSystem.config.generatedSetupScripts.testuser;
      setupHome_john     = vmSystem.config.generatedSetupScripts.john;

      #  Активат. скриптове
      activate-testuser = pkgs.writeShellScriptBin "activate-home-testuser" ''
        exec ${vmSystem.config.generatedSetupScripts.testuser}/bin/setupHome_testuser
      '';

      activate-john = pkgs.writeShellScriptBin "activate-home-john" ''
        exec ${vmSystem.config.generatedSetupScripts.john}/bin/setupHome_john
      '';
    };

    # nix run
    apps.${system}.default = {
      type = "app";
      program = "${vmSystem.config.generatedSetupScripts.testuser}/bin/setupHome_testuser";
      meta = {
      description = "Setup script for testuser's home configuration";
    };
  };
  };
  }


