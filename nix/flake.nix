{
  description = "Isala's multi-system Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Darwin (macOS)
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      nix-homebrew,
      home-manager,
    }:
    let
      # =============================================
      # Helper function to create Darwin configurations
      # =============================================
      mkDarwinSystem = { hostname, user, hostConfig, homeConfig }:
        nix-darwin.lib.darwinSystem {
          modules = [
            hostConfig
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = true;
                user = user;
                autoMigrate = true;
              };
            }
            home-manager.darwinModules.home-manager
            {
              users.users.${user} = {
                name = user;
                home = "/Users/${user}";
              };
              home-manager.backupFileExtension = "backup";
              home-manager.users.${user} = homeConfig;
            }
            {
              system.configurationRevision = self.rev or self.dirtyRev or null;
            }
          ];
        };

      # =============================================
      # Helper function to create NixOS configurations
      # (For future Ubuntu/Linux servers)
      # =============================================
      mkNixosSystem = { hostname, user, hostConfig, homeConfig }:
        nixpkgs.lib.nixosSystem {
          modules = [
            hostConfig
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.${user} = homeConfig;
            }
          ];
        };

    in
    {
      # =============================================
      # Darwin (macOS) Configurations
      # =============================================

      darwinConfigurations = {
        # M1 Office Computer
        # Usage: darwin-rebuild switch --flake .#m1-wso2
        "m1-wso2" = mkDarwinSystem {
          hostname = "m1-wso2";
          user = "isala";
          hostConfig = ./hosts/darwin/m1-wso2.nix;
          homeConfig = import ./home/isala.nix;
        };

        # M3 Personal Computer
        # Usage: darwin-rebuild switch --flake .#m3-personal
        "m3-personal" = mkDarwinSystem {
          hostname = "m3-personal";
          user = "supiri";
          hostConfig = ./hosts/darwin/m3-personal.nix;
          homeConfig = import ./home/supiri.nix;
        };
      };

      # =============================================
      # NixOS Configurations (Servers)
      # =============================================

      nixosConfigurations = {
        # Example: Ubuntu server template
        # Usage: nixos-rebuild switch --flake .#server-example
        #
        # "server-example" = mkNixosSystem {
        #   hostname = "server-example";
        #   user = "isala";
        #   hostConfig = ./hosts/nixos/server-example.nix;
        #   homeConfig = import ./home/isala-server.nix;
        # };
      };

      # =============================================
      # Expose packages for convenience
      # =============================================
      darwinPackages = self.darwinConfigurations."m1-wso2".pkgs;
    };
}
