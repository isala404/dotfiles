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
            nodejs_20
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
            pnpm
            ffmpeg
          ];
          environment.variables = {
            EDITOR = "vim";
            PATH = "$HOME/.rd/bin:$PATH";
          };

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
              "llama.cpp"
              "gemini-cli"
              "kind"
              "opencode"
            ];
            casks = [
              "spotify"
              "discord"
              "rancher"
              "brave-browser"
              "wireshark-app"
              "vlc"
              "google-chrome"
              "cursor"
              "workspace-one-intelligent-hub"
              "postman"
              "obs"
              "dbeaver-community"
              "visual-studio-code"
              "claude-code"
            ];
            masApps = {
            };
          };

          # Fonts
          fonts = {
            packages = with pkgs; [
              # nerdfonts
              nerd-fonts.jetbrains-mono # For "JetBrainsMono NF"
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
              
              # Don't add commands longer than 500 characters to history
              function fish_should_add_to_history
                test (string length -- $argv) -le 500
              end
            '';
          };
          
          programs.zsh = {
            enable = true;
            interactiveShellInit = ''
              eval "$(starship init zsh)"
            '';
          };
          
          # Set fish as the default shell
          environment.shells = [ pkgs.fish pkgs.zsh ];
          
          # Set user's default shell to fish
          users.users.isala.shell = pkgs.fish;
          
          # Enable rosetta and set default shell
          system.activationScripts.extraActivation.text = ''
            softwareupdate --install-rosetta --agree-to-license
            
            # Set fish as default shell for user
            echo "Setting fish as default shell for isala..." >&2
            dscl . -create /Users/isala UserShell /run/current-system/sw/bin/fish
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

          # Required by nix-darwin for options that apply to a specific user
          # (e.g., homebrew.enable). Set to the user who runs darwin-rebuild.
          system.primaryUser = "isala";

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
            home-manager.backupFileExtension = "backup";
            home-manager.users.isala =
              { pkgs, config, ... }:
              {
                home.packages = [ ];

                # The state version is required and should stay at the version you
                # originally installed.
                home.stateVersion = "24.11";

                programs.starship = {
                  enable = true;
                  settings = {
                    add_newline = true;
                    scan_timeout = 50;
                    command_timeout = 1000;

                    format = "$username$hostname$nix_shell$direnv$directory$git_branch$git_status$package$nodejs$bun$python$golang$rust$java$cmd_duration$fill$kubernetes$terraform$docker_context$helm$jobs$time$line_break$status$character";

                    character = {
                      success_symbol = "[❯](bold green)";
                      error_symbol = "[❯](bold red)";
                      vimcmd_symbol = "[❮](bold green)";
                    };

                    fill = {
                      symbol = " ";
                    };

                    directory = {
                      style = "bold cyan";
                      truncation_length = 3;
                      truncate_to_repo = true;
                      truncation_symbol = "…/";
                      home_symbol = "~";
                      read_only = "";
                      read_only_style = "red";
                      fish_style_pwd_dir_length = 1;
                      format = "[$path]($style)[$read_only]($read_only_style) ";
                    };

                    git_branch = {
                      symbol = " ";
                      truncation_length = 24;
                      style = "bold purple";
                      format = "[$symbol$branch]($style) ";
                    };

                    git_status = {
                      style = "bold yellow";
                      format = "([$staged$modified$untracked$stashed$conflicted$ahead_behind]($style)) ";
                      conflicted = "!$count";
                      ahead = "⇡$count";
                      behind = "⇣$count";
                      diverged = "⇕⇡$ahead_count⇣$behind_count";
                      untracked = "?$count";
                      stashed = "≡$count";
                      modified = "~$count";
                      staged = "+$count";
                    };

                    cmd_duration = {
                      min_time = 2000;
                      show_milliseconds = false;
                      style = "yellow";
                      format = "[⏱ $duration]($style) ";
                    };

                    kubernetes = {
                      disabled = false;
                      symbol = "⎈ ";
                      style = "bold cyan";
                      format = "[$symbol$context( \($namespace\))]($style) ";
                    };

                    aws = {
                      symbol = " ";
                      style = "dimmed yellow";
                      format = "[$symbol($profile)(@$region)]($style) ";
                      region_aliases = {
                        "us-east-1" = "ue1";
                        "us-west-2" = "uw2";
                        "eu-west-1" = "euw1";
                      };
                    };

                    terraform = {
                      symbol = "󱁢 ";
                      format = "[$symbol$workspace]($style) ";
                      style = "bold purple";
                    };

                    docker_context = {
                      symbol = "🐳 ";
                      format = "[$symbol$context]($style) ";
                      style = "blue";
                    };

                    helm = {
                      symbol = "⎈ ";
                      format = "[$symbol$version]($style) ";
                      style = "cyan";
                    };

                    nix_shell = {
                      symbol = " ";
                      format = "[$symbol$state( $name)]($style) ";
                      style = "bold blue";
                    };

                    direnv = {
                      disabled = false;
                      symbol = "direnv ";
                      style = "bold green";
                      format = "[$symbol]($style) ";
                    };

                    package = {
                      disabled = false;
                      symbol = "📦 ";
                      display_private = true;
                      format = "[$symbol$version]($style) ";
                    };

                    nodejs = {
                      disabled = false;
                      symbol = " ";
                      format = "[$symbol$version]($style) ";
                      style = "bold green";
                    };

                    bun = {
                      disabled = false;
                      symbol = "🍞 ";
                      format = "[$symbol$version]($style) ";
                      style = "bold yellow";
                    };

                    python = {
                      disabled = false;
                      symbol = " ";
                      pyenv_version_name = true;
                      format = "[$symbol$version( \($virtualenv\))]($style) ";
                      style = "bold blue";
                    };

                    golang = {
                      disabled = false;
                      symbol = " ";
                      format = "[$symbol$version]($style) ";
                      style = "bold cyan";
                    };

                    rust = {
                      disabled = false;
                      symbol = "🦀 ";
                      format = "[$symbol$version]($style) ";
                      style = "bold red";
                    };

                    java = {
                      disabled = false;
                      symbol = " ";
                      format = "[$symbol$version]($style) ";
                      style = "bold yellow";
                    };

                    container = {
                      symbol = "⬢ ";
                      style = "bold red";
                      format = "[$symbol$name]($style) ";
                    };

                    azure = {
                      disabled = true;
                      symbol = "az ";
                      style = "blue";
                      format = "[$symbol$subscription]($style) ";
                    };

                    shlvl = {
                      disabled = false;
                      format = "[$symbol$shlvl]($style) ";
                      repeat = false;
                      symbol = "↕ ";
                      threshold = 2;
                      style = "dimmed purple";
                    };

                    username = {
                      show_always = false;
                      style_root = "bold red";
                      style_user = "bold dimmed blue";
                      format = "[$user]($style) ";
                    };

                    hostname = {
                      ssh_only = true;
                      trim_at = ".";
                      style = "bold dimmed purple";
                      format = "[@$hostname]($style) ";
                    };

                    os = {
                      disabled = false;
                      format = "[$symbol]($style) ";
                      style = "bold white";
                      symbols = { Macos = " "; };
                    };

                    status = {
                      disabled = false;
                      style = "bold red";
                      format = "[$symbol$status]($style) ";
                      map_symbol = true;
                      symbol = "✘ ";
                    };

                    jobs = {
                      symbol = "⚙ ";
                      style = "bold cyan";
                      format = "[$symbol$number]($style) ";
                    };

                    memory_usage = {
                      disabled = false;
                      symbol = "󰍛 ";
                      threshold = 70;
                      style = "bold dimmed green";
                      format = "[$symbol$ram_pct]($style) ";
                    };

                    battery = {
                      full_symbol = " ";
                      charging_symbol = " ";
                      discharging_symbol = " ";
                      format = "[$symbol$percentage]($style) ";
                      display = [
                        { threshold = 20; style = "bold red"; }
                        { threshold = 40; style = "bold yellow"; }
                      ];
                    };

                    time = {
                      disabled = false;
                      time_format = "%R";
                      style = "dimmed white";
                      format = "[$time]($style) ";
                    };
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

                xdg.configFile."nix/nix.conf".text = ''
                  experimental-features = nix-command flakes
                '';

                # Configure VS Code / Cursor to use fish shell
                # Using home.activation to smartly merge settings without overwriting
                home.activation.configureVSCodeFish = config.lib.dag.entryAfter ["writeBoundary"] ''
                  # Function to update JSON settings
                  update_settings() {
                    local settings_file="$1"
                    local settings_dir=$(dirname "$settings_file")
                    
                    # Create directory if it doesn't exist
                    mkdir -p "$settings_dir"
                    
                    # Create settings file if it doesn't exist
                    if [ ! -f "$settings_file" ]; then
                      echo '{}' > "$settings_file"
                    fi
                    
                    # Use jq to merge settings, preserving existing values
                    ${pkgs.jq}/bin/jq '. + {
                      "terminal.integrated.defaultProfile.osx": "fish",
                      "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font, Symbols Nerd Font",
                      "terminal.integrated.fontSize": 12,
                      "terminal.integrated.profiles.osx": (."terminal.integrated.profiles.osx" // {}) + {
                        "fish": {
                          "path": "/run/current-system/sw/bin/fish"
                        }
                      }
                    }' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
                    
                    echo "Updated terminal settings in $settings_file"
                  }
                  
                  # Update Cursor settings
                  update_settings "$HOME/Library/Application Support/Cursor/User/settings.json"
                  
                  # Update VS Code settings
                  update_settings "$HOME/Library/Application Support/Code/User/settings.json"
                '';

              };
          }
        ];
      };

      darwinPacakges = self.darwinConfigurations."m1-wso2".pkgs;
    };
}
