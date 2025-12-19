# Common Darwin (macOS) configuration
# Shared across all macOS machines
# Enhanced with modern Rust CLI tools and platform engineering essentials
{ pkgs, config, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable Nix flakes
  nix.settings.experimental-features = "nix-command flakes";

  # =============================================
  # System Packages
  # =============================================
  environment.systemPackages = with pkgs; [
    # ─────────────────────────────────────────
    # Modern Rust CLI replacements (faster & better UX)
    # ─────────────────────────────────────────
    eza # ls replacement with icons & git awareness
    bat # cat replacement with syntax highlighting
    fd # find replacement, much faster
    ripgrep # grep replacement, blazing fast
    sd # sed replacement, simpler syntax
    dust # du replacement, visual disk usage
    bottom # top/htop replacement (btm command)
    procs # ps replacement with colors
    zoxide # cd replacement with smart jumping (z command)
    delta # diff viewer for git with syntax highlighting
    hyperfine # benchmarking tool
    tokei # code statistics
    # tealdeer      # tldr client - tests failing on darwin
    ouch # compression/decompression made easy
    xh # httpie/curl alternative

    # ─────────────────────────────────────────
    # Core utilities
    # ─────────────────────────────────────────
    watch
    vim
    neovim # Required for nvimdiff (git merge tool)
    mkalias
    wget
    curl
    jq
    yq-go
    fzf # fuzzy finder (essential for productivity)
    tree
    htop
    ncdu

    # ─────────────────────────────────────────
    # Git & Version Control
    # ─────────────────────────────────────────
    git
    git-lfs
    gh
    lazygit # TUI for git
    difftastic # structural diff tool

    # ─────────────────────────────────────────
    # Languages & Runtimes
    # ─────────────────────────────────────────
    go
    gopls
    golangci-lint
    rustup
    rust-analyzer # Rust LSP (also available via rustup)
    nodejs_24
    bun
    uv
    poetry

    # ─────────────────────────────────────────
    # Language Servers & Formatters (for editors)
    # ─────────────────────────────────────────
    nodePackages.prettier # JS/TS/JSON/YAML formatter
    nodePackages.typescript-language-server
    yaml-language-server # YAML LSP with Kubernetes schema support
    terraform-ls # Terraform LSP
    nil # Nix LSP
    lua-language-server # Lua LSP

    # ─────────────────────────────────────────
    # Kubernetes & Cloud (Platform Engineering)
    # ─────────────────────────────────────────
    kubectl
    kubernetes-helm
    k9s
    kustomize
    stern # multi-pod log tailing
    kubectx # fast context/namespace switching
    kubecolor # colorize kubectl output
    krew # kubectl plugin manager
    kubeconform # kubernetes manifest validation
    kube-linter # kubernetes yaml linter
    popeye # kubernetes cluster sanitizer

    # ─────────────────────────────────────────
    # Security & Scanning
    # ─────────────────────────────────────────
    trivy
    syft
    # checkov      # temporarily disabled - pyarrow build fails on Python 3.13/arm64
    grype # vulnerability scanner
    cosign # container signing
    dive # explore docker image layers

    # ─────────────────────────────────────────
    # Media
    # ─────────────────────────────────────────
    yt-dlp
    ffmpeg

    # ─────────────────────────────────────────
    # Build tools
    # ─────────────────────────────────────────
    clang
    clang-tools
    gnumake

    # ─────────────────────────────────────────
    # Shell & Terminal
    # ─────────────────────────────────────────
    starship
    fish
    tmux
    zellij # modern terminal multiplexer
    direnv # per-directory environment variables
    nix-direnv # fast direnv nix integration

    # ─────────────────────────────────────────
    # Nix tooling
    # ─────────────────────────────────────────
    nixfmt-rfc-style
    nix-tree # visualize nix derivation trees
  ];

  environment.variables = {
    EDITOR = "vim";
    # Use bat for man pages with syntax highlighting
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
  };

  # =============================================
  # Shell Aliases (applied to all shells)
  # =============================================
  environment.shellAliases = {
    # Modern CLI replacements
    ls = "eza --icons --group-directories-first";
    ll = "eza -la --icons --group-directories-first --git";
    lt = "eza -la --icons --tree --level=2";
    cat = "bat --paging=never";
    grep = "rg";
    find = "fd";
    du = "dust";
    top = "btm";
    ps = "procs";
    diff = "delta";

    # Kubernetes shortcuts
    k = "kubectl";
    kx = "kubectx";
    kn = "kubens";
    kgp = "kubectl get pods";
    kgs = "kubectl get services";
    kgd = "kubectl get deployments";
    kga = "kubectl get all";
    kdp = "kubectl describe pod";
    klf = "kubectl logs -f";
    kev = "kubectl get events --sort-by='.lastTimestamp'";

    # Git shortcuts
    g = "git";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gl = "git pull";
    gst = "git status";
    gd = "git diff";
    gco = "git checkout";
    gb = "git branch";
    glg = "lazygit";

    # Misc
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    reload = "exec $SHELL";
  };

  # =============================================
  # Fish shell
  # =============================================
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Disable greeting
      set fish_greeting

      # Initialize starship prompt
      starship init fish | source

      # Initialize zoxide (smart cd)
      zoxide init fish | source

      # Initialize direnv (per-directory environments)
      direnv hook fish | source

      # FZF configuration
      set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
      set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
      set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
      set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always --line-range :500 {}"'

      # Don't add long commands to history
      function fish_should_add_to_history
        test (string length -- $argv) -le 500
      end

      # Use bat for help pages
      function help
        $argv --help 2>&1 | bat --plain --language=help
      end
    '';
  };

  # =============================================
  # Zsh shell
  # =============================================
  programs.zsh = {
    enable = true;
    interactiveShellInit = ''
      eval "$(starship init zsh)"
      eval "$(zoxide init zsh)"
      eval "$(direnv hook zsh)"

      # FZF configuration
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    '';
  };

  # Enable shells
  environment.shells = [
    pkgs.fish
    pkgs.zsh
  ];

  # =============================================
  # Fonts (Best programming fonts)
  # =============================================
  fonts.packages = with pkgs; [
    # Primary fonts
    nerd-fonts.jetbrains-mono # Excellent ligatures, developer favorite
    nerd-fonts.fira-code # Popular ligature font
    nerd-fonts.meslo-lg # Great for powerline prompts
    nerd-fonts.caskaydia-cove # Microsoft's Cascadia Code (nerd-font name)
    nerd-fonts.hack # Clean, easy to read
    nerd-fonts.victor-mono # Cursive italics
    nerd-fonts.symbols-only # Just the icons/symbols
  ];

  # =============================================
  # Security & System
  # =============================================
  security.pam.services.sudo_local.touchIdAuth = true;

  # Create aliases for Nix apps in /Applications
  system.activationScripts.applications.text =
    let
      env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = [ "/Applications" ];
      };
    in
    pkgs.lib.mkForce ''
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

  # System settings
  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";
}
