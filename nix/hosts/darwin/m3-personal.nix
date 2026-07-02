# M3 Personal Computer Configuration
# Hostname: Isalas-M3-Pro
# User: isala
# Enhanced for platform engineering + personal use
{ pkgs, config, ... }:
let
  # Derive paths from config so no machine-specific tree is hardcoded in source.
  # `~/.dotfiles` is a symlink to the real checkout, created at runtime by
  # post-rebuild.sh — the actual location never appears in tracked source.
  homeDir = config.users.users.${config.system.primaryUser}.home;
  dotfilesDir = "${homeDir}/.dotfiles";
in
{
  imports = [
    ../../modules/darwin/common.nix
  ];

  # This machine's rebuild shortcut (kept here, not in the shared module).
  environment.shellAliases.sync-m3 =
    "sudo darwin-rebuild switch --flake ${dotfilesDir}/nix#m3-personal && ${dotfilesDir}/bin/post-rebuild.sh";

  # =============================================
  # Additional Packages for Personal Machine
  # =============================================
  environment.systemPackages = with pkgs; [
    # ─────────────────────────────────────────
    # Cloud & Infrastructure
    # ─────────────────────────────────────────
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

    # ─────────────────────────────────────────
    # Security Tools
    # ─────────────────────────────────────────
    kubeseal # Sealed secrets
    sops # Secret encryption
    git-crypt # Transparent file encryption in git
    cloudflared # Cloudflare tunnels
    nmap

    # ─────────────────────────────────────────
    # Build & Development Tools
    # ─────────────────────────────────────────
    cmake
    gnupg
    imagemagick

    # ─────────────────────────────────────────
    # Cross-compilation (zig as CC/CXX for linux-amd64)
    # ─────────────────────────────────────────
    (pkgs.writeShellScriptBin "zig-cc-x86_64-linux-gnu" ''
      exec ${pkgs.zig}/bin/zig cc -target x86_64-linux-gnu "$@"
    '')
    (pkgs.writeShellScriptBin "zig-cxx-x86_64-linux-gnu" ''
      exec ${pkgs.zig}/bin/zig c++ -target x86_64-linux-gnu "$@"
    '')
  ];

  environment.variables = {
    PATH = "$HOME/.cargo/bin:$HOME/.npm-global/bin:$HOME/.orbstack/bin:$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator:$PATH";
    ANDROID_HOME = "$HOME/Library/Android/sdk";
    ANDROID_SDK_ROOT = "$HOME/Library/Android/sdk";
  };

  # =============================================
  # Fish Shell - Personal paths and tools
  # =============================================
  programs.fish.interactiveShellInit = ''
    # libiconv for native (non-cross) Rust/C builds
    set -gx LIBRARY_PATH "${pkgs.libiconv}/lib"

    # Paths
    fish_add_path ~/.local/bin
    fish_add_path ~/.cargo/bin
    fish_add_path /usr/local/bin
    fish_add_path ~/.orbstack/bin
    fish_add_path ~/.npm-global/bin
    fish_add_path ~/Library/Android/sdk/platform-tools
    fish_add_path ~/Library/Android/sdk/emulator

    # OrbStack shell init
    source ~/.orbstack/shell/init.fish 2>/dev/null; or true

    # Cross-compile Go with CGo to linux/amd64
    function go-linux-amd64
      CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
        CC="zig cc -target x86_64-linux-gnu" \
        CXX="zig c++ -target x86_64-linux-gnu" \
        go $argv
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
      sudo darwin-rebuild switch --flake ${dotfilesDir}/nix#m3-personal
    end
  '';

  programs.zsh.interactiveShellInit = ''
    # libiconv for native (non-cross) Rust/C builds
    export LIBRARY_PATH="${pkgs.libiconv}/lib"

    export PATH="$HOME/.bun/bin:$PATH"
    export PATH="$HOME/.cargo/bin:$PATH"
    export PATH="$HOME/.orbstack/bin:$PATH"

    source ~/.orbstack/shell/init.zsh 2>/dev/null || :
    [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
  '';

  # =============================================
  # Homebrew - Personal-only additions
  # =============================================
  nix-homebrew.enableBashIntegration = false;
  nix-homebrew.enableFishIntegration = false;
  nix-homebrew.enableZshIntegration = false;

  homebrew = {
    taps = [
      "steipete/tap"
    ];

    brews = [
      "llvm" # clang/clang-tools without Nix's cc-wrapper
    ];

    casks = [
      # Development
      "cursor"
      "zed"
      "ghostty"
      "orbstack"
      "t3-code"
      "android-studio"
      "android-commandlinetools"
      "temurin"

      # Communication
      "whatsapp"

      # Tools
      "steipete/tap/codexbar"

      # Utilities
      "aldente"
      "capcut"
      "macs-fan-control"
      "transmission"
      "google-drive"

      # Network & Security
      "openvpn-connect"
      "tailscale-app"
    ];

    masApps = { };
  };

  # =============================================
  # M3-specific activation (keychain-bio, credential helpers, Time Machine)
  # =============================================
  system.activationScripts.extraActivation.text = ''
    # Compile and install keychain-bio (Touch ID gated keychain access).
    # Sources are referenced as nix store paths so no checkout location leaks.
    echo "Building keychain-bio..." >&2
    mkdir -p ${homeDir}/.local/bin
    swiftc -O -o ${homeDir}/.local/bin/keychain-bio ${../../../bin/keychain-bio.swift} \
      -framework Security -framework LocalAuthentication 2>&1 | logger -t keychain-bio || true

    # Install BWS credential helpers
    install -m 755 ${../../../bin/bws/aws-credential-helper.sh} ${homeDir}/.aws/bws-credential-helper.sh 2>/dev/null || true
    install -m 755 ${../../../bin/bws/kube-credential-helper.sh} ${homeDir}/.kube/bws-credential-helper.sh 2>/dev/null || true

    # Time Machine exclusions — skip reproducible/cacheable data
    echo "Configuring Time Machine exclusions..." >&2
    for dir in \
      /nix \
      ${homeDir}/.cargo \
      ${homeDir}/.rustup \
      ${homeDir}/.npm-global \
      ${homeDir}/go \
      ${homeDir}/Library/Android/sdk \
      ${homeDir}/Library/Developer/Xcode/DerivedData \
      ${homeDir}/Library/Developer/CoreSimulator \
      ${homeDir}/Library/Caches \
      ${homeDir}/.cache \
      ${homeDir}/.gradle \
      ${homeDir}/.cocoapods \
      ${homeDir}/.pub-cache \
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
      find ${homeDir}/Projects -maxdepth 4 -type d -name "$pattern" -exec tmutil addexclusion {} \; 2>/dev/null || true
    done

    # ML model caches
    for dir in \
      ${homeDir}/.cache/huggingface \
      ${homeDir}/.cache/torch \
      ${homeDir}/.cache/pip \
      ${homeDir}/.cache/uv \
      ${homeDir}/.ollama \
      ${homeDir}/.lmstudio \
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
      darwin-rebuild switch --flake ${dotfilesDir}/nix#m3-personal 2>&1 | logger -t nix-sync
      sudo -u ${config.system.primaryUser} /bin/sh -lc 'bunx skills add https://github.com/isala404/dotfiles/tree/main/skills -g --agent claude-code codex -y' 2>&1 | logger -t nix-sync
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
}
