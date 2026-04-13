# M3 Personal Computer Configuration
# Hostname: Isalas-M3-Pro
# User: isala
# Enhanced for platform engineering + personal use
{ pkgs, ... }:
{
  imports = [
    ../../modules/darwin/common.nix
  ];

  # =============================================
  # Additional Packages for Personal Machine
  # =============================================
  environment.systemPackages = with pkgs; [
    # ─────────────────────────────────────────
    # Cloud & Infrastructure
    # ─────────────────────────────────────────
    awscli2
    google-cloud-sdk
    eksctl # EKS management
    terraform
    opentofu # Open-source Terraform
    (azure-cli.withExtensions [
      azure-cli.extensions.aks-preview
    ])

    # ─────────────────────────────────────────
    # GitOps & CD
    # ─────────────────────────────────────────
    flux # GitOps toolkit
    argocd # GitOps CD
    kustomize # (already in common, but explicit here)

    # ─────────────────────────────────────────
    # Security Tools
    # ─────────────────────────────────────────
    kubeseal # Sealed secrets
    sops # Secret encryption
    git-crypt # Transparent file encryption in git
    bws # Bitwarden Secrets Manager CLI
    cloudflared # Cloudflare tunnels
    nmap
    # ─────────────────────────────────────────
    # Build & Development Tools
    # ─────────────────────────────────────────
    cmake
    gnupg
    imagemagick
  ];

  environment.variables = {
    PATH = "$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.npm-global/bin:$HOME/.orbstack/bin:$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator:$PATH";
    ANDROID_HOME = "$HOME/Library/Android/sdk";
    ANDROID_SDK_ROOT = "$HOME/Library/Android/sdk";
  };

  # =============================================
  # Fish Shell - Personal paths and tools
  # =============================================
  programs.fish.interactiveShellInit = ''
    set fish_greeting
    starship init fish | source
    zoxide init fish | source
    direnv hook fish | source

    # FZF configuration
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
    set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always --line-range :500 {}"'

    function fish_should_add_to_history
      test (string length -- $argv) -le 500
    end

    # libiconv for native (non-cross) Rust/C builds
    set -gx LIBRARY_PATH "${pkgs.libiconv}/lib"

    # Paths
    fish_add_path ~/.local/bin
    fish_add_path ~/.bun/bin
    fish_add_path ~/.cargo/bin
    fish_add_path /usr/local/bin
    fish_add_path ~/.orbstack/bin
    fish_add_path ~/.npm-global/bin
    fish_add_path ~/Library/Android/sdk/platform-tools
    fish_add_path ~/Library/Android/sdk/emulator

    # OrbStack shell init
    source ~/.orbstack/shell/init.fish 2>/dev/null; or true

    # Use kubecolor for kubectl output
    function kubectl
      command kubecolor $argv
    end

    # Quick project navigation
    function proj
      cd ~/Projects && cd (fd --type d --max-depth 2 | fzf)
    end

    # Quick kubernetes context switch
    function kctx
      kubectx (kubectx | fzf)
    end

    # Quick kubernetes namespace switch
    function kns
      kubens (kubens | fzf)
    end

    # BWS wrapper: fetch token from keychain with Touch ID gate
    function bws
      set -lx BWS_ACCESS_TOKEN (~/.local/bin/keychain-bio get bws-access-token)
      command bws $argv
    end

    # Sync system config
    function sync
      echo "Syncing nix-darwin config..."
      sudo darwin-rebuild switch --flake ~/Projects/dotfiles/nix#m3-personal
    end
  '';

  programs.zsh.interactiveShellInit = ''
    eval "$(starship init zsh)"
    eval "$(zoxide init zsh)"
    eval "$(direnv hook zsh)"

    # libiconv for native (non-cross) Rust/C builds
    export LIBRARY_PATH="${pkgs.libiconv}/lib"

    export PATH="$HOME/.bun/bin:$PATH"
    export PATH="$HOME/.cargo/bin:$PATH"
    export PATH="$HOME/.orbstack/bin:$PATH"

    source ~/.orbstack/shell/init.zsh 2>/dev/null || :
    [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

  '';

  # =============================================
  # Homebrew - Personal Applications
  # =============================================
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    brews = [
      "mas"
      "gemini-cli"
      "opencode"
      "llvm"         # clang/clang-tools without Nix's cc-wrapper
    ];

    casks = [
      # Browsers
      "google-chrome"

      # Development
      "visual-studio-code"
      "cursor"
      "zed"
      "ghostty"
      "dbeaver-community"
      "postman"
      "orbstack"
      "claude-code"
      "codex"
      "t3-code"
      "android-studio"
      "android-commandlinetools"
      "temurin"

      # Communication
      "discord"
      "slack"
      "whatsapp"

      # Media
      "spotify"
      "vlc"
      "obs"
      # Utilities
      "aldente"
      "macs-fan-control"
      "transmission"
      "google-drive"

      # Network & Security
      "bitwarden"
      "openvpn-connect"
      "tailscale-app"
    ];

    masApps = {
      Xcode = 497799835;
    };
  };

  # =============================================
  # User Configuration
  # =============================================
  users.users.isala.shell = pkgs.fish;

  system.activationScripts.extraActivation.text = ''
    softwareupdate --install-rosetta --agree-to-license
    echo "Setting fish as default shell for isala..." >&2
    dscl . -create /Users/isala UserShell /run/current-system/sw/bin/fish

    # Compile and install keychain-bio (Touch ID gated keychain access)
    echo "Building keychain-bio..." >&2
    mkdir -p /Users/isala/.local/bin
    DOTFILES="/Users/isala/Projects/dotfiles"
    swiftc -O -o /Users/isala/.local/bin/keychain-bio "$DOTFILES/bin/keychain-bio.swift" \
      -framework Security -framework LocalAuthentication 2>&1 | logger -t keychain-bio || true

    # Install BWS credential helpers
    install -m 755 "$DOTFILES/bin/bws/aws-credential-helper.sh" /Users/isala/.aws/bws-credential-helper.sh 2>/dev/null || true
    install -m 755 "$DOTFILES/bin/bws/kube-credential-helper.sh" /Users/isala/.kube/bws-credential-helper.sh 2>/dev/null || true

    # Time Machine exclusions — skip reproducible/cacheable data
    echo "Configuring Time Machine exclusions..." >&2
    for dir in \
      /nix \
      /Users/isala/.cargo \
      /Users/isala/.rustup \
      /Users/isala/.npm-global \
      /Users/isala/go \
      /Users/isala/Library/Android/sdk \
      /Users/isala/Library/Developer/Xcode/DerivedData \
      /Users/isala/Library/Developer/CoreSimulator \
      /Users/isala/Library/Caches \
      /Users/isala/.cache \
      /Users/isala/.gradle \
      /Users/isala/.cocoapods \
      /Users/isala/.pub-cache \
    ; do
      tmutil addexclusion -p "$dir" 2>/dev/null || true
    done

    # Exclude node_modules, build artifacts, venvs, and model caches
    # Uses sticky exclusion on common paths
    for pattern in \
      node_modules \
      .next \
      target \
      .venv \
      venv \
      __pycache__ \
      .tox \
      dist \
      build \
    ; do
      find /Users/isala/Projects -maxdepth 4 -type d -name "$pattern" -exec tmutil addexclusion {} \; 2>/dev/null || true
    done

    # ML model caches
    for dir in \
      /Users/isala/.cache/huggingface \
      /Users/isala/.cache/torch \
      /Users/isala/.cache/pip \
      /Users/isala/.cache/uv \
      /Users/isala/.ollama \
      /Users/isala/.lmstudio \
    ; do
      tmutil addexclusion -p "$dir" 2>/dev/null || true
    done
  '';

  # =============================================
  # Weekly Nix Sync (Fridays at 11pm)
  # =============================================
  launchd.daemons.nix-weekly-sync = {
    script = ''
      export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      darwin-rebuild switch --flake /Users/isala/Projects/dotfiles/nix#m3-personal 2>&1 | logger -t nix-sync
    '';
    serviceConfig = {
      StartCalendarInterval = [{
        Weekday = 5;
        Hour = 23;
        Minute = 0;
      }];
      StandardOutPath = "/var/log/nix-sync.log";
      StandardErrorPath = "/var/log/nix-sync.log";
    };
  };

  system.primaryUser = "isala";
}
