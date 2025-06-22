# vim: set sw=2 expandtab:
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs   = import nixpkgs { inherit system; };
    lib    = pkgs.lib;

    # потребителски файлове
    userConfigs = {
      testuser = {
        homeFiles = {
          # Съдържание на ~/.bashrc за testuser
          ".bashrc" = {
            text = ''
              # Първоначална настройка при първо влизане
              if [ ! -f "$HOME/.home-setup.done" ]; then
                /etc/profiles/per-user/$USER/bin/setupHome_$USER
                touch "$HOME/.home-setup.done"
              fi
              echo "Hello from testuser!"
            '';
            mode = "600";             
            };

          # Прост vim конфиг
          ".vimrc" = { text = "set number\nsyntax on"; mode = "644"; };

          # лесен скрипт
          "my_script.sh" = { source = ./my_script.sh; mode = "755"; };

          # Алиаси
          ".my_aliases" = { source = ./my_aliases; mode = "644"; };
        };
      };

      john = {
        homeFiles = {
          # ~/.bashrc за John
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

          # същия скрипт за John
          "my_script.sh" = { source = ./my_script.sh; mode = "755"; };
        };
      };
    };

  in
  {
    nixosModules = {
      systemExtras = ./systemExtras.nix;      # системни настройки
      homeSetup    = ./homeSetup.nix;         # home-setup модула
    };

    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.systemExtras
        self.nixosModules.homeSetup           # Зареждаме homeSetup
        {
          # Подаваме конфигурации
          homeSetups = userConfigs;

          # Дефинираме потребители
          users.users.testuser = {
            isNormalUser    = true;
            initialPassword = "test";
            extraGroups     = [ "wheel" ];
            packages        = [ pkgs.vim ];  
            };
          users.users.john = {
            isNormalUser    = true;
            initialPassword = "john1";
            extraGroups     = [ "wheel" ];
          };

          # Коп. всички дефинирани homeFiles в /etc/home/…
          virtualisation.vmVariant.environment.etc =
            lib.foldl'
              (acc: user:
                lib.foldl'
                  (acc2: fileName:
                    let
                      file     = userConfigs.${user}.homeFiles.${fileName};
                      destPath = "home/${user}/${fileName}";
                      src      = if file ? text
                                 then pkgs.writeText "inline-${user}-${fileName}" file.text
                                 else file.source;
                    in
                      acc2 // {
                        "${destPath}" = {
                          source = src;
                          mode   = file.mode;
                        };
                      }
                  )
                  acc
                  (lib.attrNames userConfigs.${user}.homeFiles)
              )
              {}
              (lib.attrNames userConfigs);

          system.stateVersion = "24.11";     # версията на NixOS
        }
      ];
    };

    # локална активация
    packages.${system} = {
      # ползваме скриптовете от модула
      activate-testuser = pkgs.writeShellScriptBin "activate-home-testuser" ''
        /etc/profiles/per-user/testuser/bin/setupHome_testuser
      '';
      activate-john = pkgs.writeShellScriptBin "activate-home-john" ''
        /etc/profiles/per-user/john/bin/setupHome_john
      '';
    };

    apps.${system}.default = {
      type    = "app";
      program = "${self.packages.${system}.activate-testuser}/bin/activate-home-testuser";
    };
  };
}

