# vim: set sw=2 expandtab:
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs   = import nixpkgs { inherit system; };
    lib    = pkgs.lib;

    # конфиг. за всеки потребител и файловете му
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
          "banica/my_script.sh" = { source = ./my_script.sh; mode = "755"; };
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

    # VM конфигурация users
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
            packages = [ pkgs.vim vmSystem.config.generatedSetupScripts.testuser];
            createHome = true;
            home = "/home/testuser";
          };

          users.users.john = {
            isNormalUser = true;
            initialPassword = "john1";
            extraGroups = [ "wheel" ];
            createHome = true;
            home = "/home/john/";
          };
           
          #  (userActivationScripts не се пускат автоматично при nix build .#vm) ->затова този блок
          systemd.services.run-user-home-setup = {
            description = "Run setupHome script for users";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "run-user-home-setup" ''
                for user in ${lib.concatStringsSep " " (lib.attrNames userConfigs)}; do
                  script="/etc/profiles/per-user/$user/bin/setupHome_$user"
                  if [ -x "$script" ] && [ ! -f "/home/$user/.home-setup.done" ]; then
                    echo "🏁 Running $script" >> /tmp/home-setup.log
                      ${pkgs.util-linux}/bin/runuser -u "$user" -- "$script"
                  fi
                done
              '';
            };
          };

          #  Копиране на файлове в home/... -> за достъп във VM
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

    
    nixosConfigurations.vm = vmSystem;

    #  Пакети (локално ползване)
    packages.${system} = {
      #  Скриптовете setupHome_{user} са експортирани от homeSetup
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

