{
  

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      # Конфигурация homeFiles
      config = {
        homeFiles.".bashrc" = {
          text = ''
            export PATH=$PATH:$HOME/mybin
            echo "Hello from symlink bash"
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



      #  модула и генериране на setup script
      homeSetup = import ./homeSetup.nix { inherit config lib pkgs; };
      setupScript = pkgs.writeShellScriptBin "activate-home" homeSetup.config.system.userActivationScripts.setupHome.text;

    in
    {
      # директно изпълнение: nix run .#activate
      packages.${system}.activate = setupScript;

      # потребители: nix run github:angelubuntu/home-setup
      apps.${system}.default = {
        type = "app";
        program = "${setupScript}/bin/activate-home";
      };

      # импорт в други nixosConfigurations
      nixosModules = {
      homeSetup = ./homeSetup.nix;
      systemExtras = ./systemExtras.nix;
    };
    
	nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
  	system = "x86_64-linux";

  	modules = [
    	self.nixosModules.systemExtras
    	self.nixosModules.homeSetup

    {
      users.users.testuser = {
        isNormalUser = true;
        initialPassword = "test";
        extraGroups = [ "wheel" ];

      };
       
	system.stateVersion = "24.11";
        
	}
        ];
      };
      };
      }





