# M3 Personal Computer Configuration
# Hostname: Isalas-M3-Pro
# User: supiri
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
    age # Modern encryption
    cloudflared # Cloudflare tunnels
    nmap
    mtr # Network diagnostics

    # ─────────────────────────────────────────
    # Build & Development Tools
    # ─────────────────────────────────────────
    cmake
    gnupg
    swig
    cocoapods # iOS development

    # ─────────────────────────────────────────
    # Document & Typesetting
    # ─────────────────────────────────────────
    tectonic # Modern LaTeX
    typst # Modern typesetting
    tesseract # OCR
    pandoc # Document conversion

    # ─────────────────────────────────────────
    # File Management
    # ─────────────────────────────────────────
    yazi # Terminal file manager
    imagemagick # Image manipulation
  ];

  environment.variables = {
    PATH = "$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.lmstudio/bin:$HOME/.orbstack/bin:$PATH";
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

    # Paths
    fish_add_path ~/.bun/bin
    fish_add_path ~/.cargo/bin
    fish_add_path /usr/local/bin
    fish_add_path ~/.orbstack/bin
    fish_add_path ~/.lmstudio/bin

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
  '';

  programs.zsh.interactiveShellInit = ''
    eval "$(starship init zsh)"
    eval "$(zoxide init zsh)"
    eval "$(direnv hook zsh)"

    export PATH="$HOME/.bun/bin:$PATH"
    export PATH="$HOME/.cargo/bin:$PATH"
    export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
    export PATH="$HOME/.lmstudio/bin:$PATH"
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
      "llama.cpp"
      "gemini-cli"
      "opencode"
    ];

    casks = [
      # Browsers
      "google-chrome"

      # Development
      "visual-studio-code"
      "cursor"
      "zed"
      "alacritty"
      "wezterm" # Alternative terminal
      "dbeaver-community"
      "postman"
      "orbstack" # Docker & Linux VMs
      "claude-code"

      # AI/ML
      "lm-studio"

      # Communication
      "discord"
      "slack"
      "whatsapp"

      # Media
      "spotify"
      "vlc"
      "obs"
      "iina" # Modern video player

      # Utilities
      "aldente"
      "macs-fan-control"
      "transmission"
      "google-drive"
      "raycast" # Spotlight replacement

      # Gaming & Emulation
      "steam"

      # Network & Security
      "openvpn-connect"
      "tailscale"
      "wireshark-app"
    ];

    masApps = { };
  };

  # =============================================
  # User Configuration
  # =============================================
  users.users.supiri.shell = pkgs.fish;

  system.activationScripts.extraActivation.text = ''
    softwareupdate --install-rosetta --agree-to-license
    echo "Setting fish as default shell for supiri..." >&2
    dscl . -create /Users/supiri UserShell /run/current-system/sw/bin/fish
  '';

  system.primaryUser = "supiri";
}
