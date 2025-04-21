{
  description = "Isala's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    # Manages configs links things into your home directory
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      home-manager,
      nixpkgs,
      nix-homebrew,
    }:
    let
      configuration =
        {
          pkgs,
          config,
          ...
        }:
        {
          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          nixpkgs.config.allowUnfree = true;

          environment.systemPackages = with pkgs; [
            watch
            vim
            mkalias
            go
            rustup
            git
            git-lfs
            kubectl
            kubernetes-helm
            k9s
            bun
            uv
            starship
            nodejs_23
            poetry
            (azure-cli.withExtensions [
              azure-cli.extensions.aks-preview
              azure-cli.extensions.bastion
              azure-cli.extensions.ssh
            ])
            nixfmt-rfc-style
            gh
            kubelogin
            cilium-cli
            hubble
            yt-dlp
          ];
          environment.variables.EDITOR = "vim";

          homebrew = {
            enable = true;
            onActivation = {
              autoUpdate = true; # Fetch the newest stable branch of Homebrew's git repo
              upgrade = true; # Upgrade outdated casks, formulae, and App Store apps
              # 'zap': uninstalls all formulae(and related files) not listed in the generated Brewfile
              cleanup = "zap";
            };
            brews = [
              "mas"
              "jmeter"
            ];
            casks = [
              "spotify"
              "discord"
              "rancher"
              "brave-browser"
              "wireshark"
              "vlc"
              "google-chrome"
              "cursor"
              "workspace-one-intelligent-hub"
            ];
            masApps = {
            };
          };

          # Fonts
          fonts = {
            packages = with pkgs; [
              # icon fonts
              material-design-icons
              font-awesome

              # nerdfonts
              nerd-fonts.symbols-only # For "NerdFontsSymbolsOnly"
              nerd-fonts.fira-code # For "FiraCode"
              nerd-fonts.jetbrains-mono # For "JetBrainsMono"
              nerd-fonts.iosevka # For "Iosevka"
            ];
          };
          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          # Enable alternative shell support in nix-darwin.
          programs.fish = {
            enable = true;
            interactiveShellInit = ''
              set fish_greeting
              starship init fish | source
            '';
          };
          
          programs.zsh = {
            enable = true;
            interactiveShellInit = ''
              eval "$(starship init zsh)"
            '';
          };
          # Enable rosetta
          system.activationScripts.extraActivation.text = ''
            softwareupdate --install-rosetta --agree-to-license
          '';

          system.activationScripts.applications.text =
            let
              env = pkgs.buildEnv {
                name = "system-applications";
                paths = config.environment.systemPackages;
                pathsToLink = "/Applications";
              };
            in
            pkgs.lib.mkForce ''
              # Set up applications.
              echo "setting up /Applications..." >&2
              rm -rf /Applications/Nix\ Apps
              mkdir -p /Applications/Nix\ Apps
              find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
              while read -r src; do
                app_name=$(basename "$src")
                echo "copying $src" >&2
                ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
              done
            '';

          # Enable sudo touch id auth
          security.pam.services.sudo_local.touchIdAuth = true;

          # Set Git commit hash for darwin-version.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          system.stateVersion = 6;

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";
        };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#simple
      darwinConfigurations."m1-wso2" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              # Install Homebrew under the default prefix
              enable = true;

              # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
              enableRosetta = true;

              # User owning the Homebrew prefix
              user = "isala";

              # Automatically migrate existing Homebrew installations
              autoMigrate = true;
            };
          }
          home-manager.darwinModules.home-manager
          {
            users.users.isala = {
              name = "isala";
              home = "/Users/isala";
            };
            home-manager.users.isala =
              { pkgs, ... }:
              {
                home.packages = [ ];

                # The state version is required and should stay at the version you
                # originally installed.
                home.stateVersion = "24.11";

                programs.starship = {
                  enable = true;
                  settings = {
                  };
                };

                programs.git = {
                  enable = true;
                  userName = "Isala";
                  userEmail = "mail@isala.me";
                  aliases = {
                    lol = "log --graph --decorate --pretty=oneline --abbrev-commit --all";

                    # Get the current branch name (not so useful in itself, but used in
                    # other aliases)
                    branch-name = "!git rev-parse --abbrev-ref HEAD";

                    # Push the current branch to the remote "origin", and set it to track
                    # the upstream branch
                    publish = "!git push -u origin $(git branch-name)";

                    # Delete the remote version of the current branch
                    unpublish = "!git push origin :$(git branch-name)";

                    # Switch branches via fzf
                    fzf = "!git checkout $(git branch --color=always --all --sort=-committerdate | grep -v HEAD | fzf --height 50% --ansi --no-multi --preview-window right:65%  --preview 'git log -n 50 --color=always --date=short --pretty=\"format:%C(auto)%cd %h%d %s\" $(sed \"s/.* //\" <<< {})' | sed \"s/.* //\")";
                  };

                  ignores = [ ".DS_Store" ];

                  extraConfig = {
                    init = {
                      defaultBranch = "main";
                    };

                    core = {
                      ignorecase = "false";
                    };

                    pull = {
                      rebase = false;
                    };

                    push = {
                      autoSetupRemote = true;
                    };

                    diff = {
                      external = "difft";
                      tool = "nvimdiff";
                    };

                    merge = {
                      tool = "nvimdiff";
                    };

                    "merge \"npm-merge-driver\"" = {
                      name = "automatically merge npm lockfiles";
                      driver = "npx npm-merge-driver merge %A %O %B %P";
                    };

                    difftool = {
                      prompt = true;
                    };

                    "difftool \"nvimdiff\"" = {
                      cmd = "nvim -d \"$LOCAL\" \"$REMOTE\"";
                    };
                  };
                };

              };
          }
        ];
      };

      darwinPacakges = self.darwinConfigurations."m1-wso2".pkgs;
    };
}
