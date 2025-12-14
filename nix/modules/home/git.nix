# Shared Git configuration
# Enhanced with delta for beautiful diffs and useful aliases
{ lib, pkgs, ... }:
{
  programs.git = {
    enable = true;
    # These should be overridden per-user
    userName = lib.mkDefault "Isala";
    userEmail = lib.mkDefault "mail@isala.me";

    lfs.enable = true;

    # =============================================
    # Git Aliases
    # =============================================
    aliases = {
      # Log visualization
      lol = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      last = "log -1 HEAD --stat";
      today = "log --since=midnight --author='Isala' --oneline";

      # Branch operations
      branch-name = "!git rev-parse --abbrev-ref HEAD";
      publish = "!git push -u origin $(git branch-name)";
      unpublish = "!git push origin :$(git branch-name)";
      branches = "branch -a --sort=-committerdate";
      recent = "branch --sort=-committerdate --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative))%(color:reset)'";

      # Status shortcuts
      st = "status -sb";
      s = "status -sb";

      # Commit shortcuts
      cm = "commit -m";
      ca = "commit --amend";
      can = "commit --amend --no-edit";

      # Diff shortcuts
      d = "diff";
      dc = "diff --cached";
      ds = "diff --stat";

      # Checkout shortcuts
      co = "checkout";
      cob = "checkout -b";

      # Reset shortcuts
      unstage = "reset HEAD --";
      undo = "reset --soft HEAD~1";

      # Stash shortcuts
      stl = "stash list";
      stp = "stash pop";
      sts = "stash save";

      # Clean shortcuts
      cleanup = "!git branch --merged | grep -v '\\*\\|main\\|master\\|develop' | xargs -n 1 git branch -d";

      # Interactive operations with fzf
      fzf = ''!git checkout $(git branch --color=always --all --sort=-committerdate | grep -v HEAD | fzf --height 50% --ansi --no-multi --preview-window right:65% --preview 'git log -n 50 --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' | sed "s/.* //")'';
      fza = "!git add $(git status -s | fzf --multi --preview 'git diff --color=always {2}' | awk '{print $2}')";

      # Useful info
      aliases = "config --get-regexp alias";
      whoami = "config user.email";
    };

    # =============================================
    # Global Ignore Patterns
    # =============================================
    ignores = [
      # macOS
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      "._*"

      # Editors
      "*.swp"
      "*.swo"
      "*~"
      ".idea/"
      ".vscode/"
      "*.sublime-*"

      # Environment
      ".env"
      ".env.local"
      ".env.*.local"
      ".envrc"

      # Languages
      "*.pyc"
      "__pycache__/"
      "node_modules/"
      ".npm"
      "vendor/"

      # Build artifacts
      "*.log"
      "*.tmp"
      "dist/"
      "build/"
      "target/"

      # Nix
      ".direnv/"
      "result"
      "result-*"
    ];

    # =============================================
    # Delta Configuration (Beautiful diffs)
    # =============================================
    delta = {
      enable = true;
      options = {
        features = "decorations";
        navigate = true;    # Use n/N to move between diff sections
        side-by-side = false;
        line-numbers = true;
        syntax-theme = "OneHalfDark";

        # Decorations
        decorations = {
          commit-decoration-style = "bold yellow box ul";
          file-style = "bold yellow ul";
          file-decoration-style = "none";
          hunk-header-decoration-style = "cyan box ul";
        };

        # Line numbers
        line-numbers-left-format = "{nm:>4}│";
        line-numbers-right-format = "{np:>4}│";
        line-numbers-left-style = "cyan";
        line-numbers-right-style = "cyan";
        line-numbers-minus-style = "red";
        line-numbers-plus-style = "green";

        # Diff colors
        minus-style = "syntax #3f2d3d";
        minus-emph-style = "syntax #763842";
        plus-style = "syntax #283b4d";
        plus-emph-style = "syntax #316172";

        # Blame
        blame-palette = "#1e1e2e #313244 #45475a";

        # Merge conflicts
        merge-conflict-begin-symbol = "▼";
        merge-conflict-end-symbol = "▲";
        merge-conflict-ours-diff-header-style = "yellow bold";
        merge-conflict-theirs-diff-header-style = "yellow bold italic";
      };
    };

    # =============================================
    # Extra Git Configuration
    # =============================================
    extraConfig = {
      init.defaultBranch = "main";

      core = {
        ignorecase = false;
        autocrlf = "input";
        editor = "vim";
        pager = "delta";
      };

      # Pull/Push behavior
      pull.rebase = lib.mkDefault true;
      push = {
        autoSetupRemote = true;
        default = "current";
      };

      # Fetch behavior
      fetch = {
        prune = true;
        pruneTags = true;
      };

      # Rebase settings
      rebase = {
        autoStash = true;
        autoSquash = true;
      };

      # Merge settings
      merge = {
        tool = "nvimdiff";
        conflictstyle = "diff3";
      };

      # Diff settings (delta handles most of this)
      diff = {
        colorMoved = "default";
        algorithm = "histogram";
      };

      interactive.diffFilter = "delta --color-only";

      # URL shortcuts
      "url \"git@github.com:\"" = {
        insteadOf = "gh:";
      };
      "url \"git@gitlab.com:\"" = {
        insteadOf = "gl:";
      };

      # Better merge conflict markers
      "merge \"npm-merge-driver\"" = {
        name = "automatically merge npm lockfiles";
        driver = "npx npm-merge-driver merge %A %O %B %P";
      };

      # Rerere - remember merge conflict resolutions
      rerere.enabled = true;

      # Column output for branch, status, tag
      column.ui = "auto";

      # Better colors
      color = {
        ui = "auto";
        branch = {
          current = "yellow reverse";
          local = "yellow";
          remote = "green";
        };
        status = {
          added = "green";
          changed = "yellow";
          untracked = "red";
        };
      };

      # Help with typos
      help.autocorrect = 10;
    };
  };
}
