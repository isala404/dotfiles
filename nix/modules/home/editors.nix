# Editor configurations (VS Code, Cursor, Zed, Alacritty)
# Enhanced with better settings for platform engineers
{ pkgs, config, lib, ... }:
{
  # =============================================
  # Zed Editor Configuration
  # =============================================
  xdg.configFile."zed/settings.json".text = builtins.toJSON {
    # Theme & Appearance
    theme = {
      mode = "system";
      light = "One Light";
      dark = "One Dark Pro";
    };
    icon_theme = "Catppuccin Latte";

    # Fonts
    ui_font_size = 15;
    ui_font_family = "JetBrainsMono Nerd Font";
    buffer_font_size = 14;
    buffer_font_family = "JetBrainsMono Nerd Font";
    buffer_font_features = {
      calt = true;   # Contextual alternates (ligatures)
      liga = true;   # Standard ligatures
    };

    # Editor behavior
    vim_mode = false;
    cursor_blink = false;
    show_whitespaces = "selection";
    soft_wrap = "editor_width";
    tab_size = 2;
    format_on_save = "on";
    autosave = "on_focus_change";
    remove_trailing_whitespace_on_save = true;

    # Git integration
    git = {
      inline_blame.enabled = true;
      git_gutter = "tracked_files";
    };
    git_panel.sort_by_path = false;

    # Terminal
    terminal = {
      shell.program = "/run/current-system/sw/bin/fish";
      font_family = "JetBrainsMono Nerd Font";
      font_size = 13;
      line_height.custom = 1.2;
      blinking = "off";
      copy_on_select = true;
    };

    # AI/Agent settings
    agent = {
      default_model = {
        provider = "copilot_chat";
        model = "claude-sonnet-4-20250514";
      };
      model_parameters = [];
    };

    # Language-specific settings
    languages = {
      # YAML with Kubernetes schema support
      YAML = {
        tab_size = 2;
        formatter = "language_server";
        language_servers = ["yaml-language-server" "..."];
      };
      # Terraform/HCL
      Terraform = {
        tab_size = 2;
        formatter = "language_server";
      };
      # Go
      Go = {
        tab_size = 4;
        formatter = "language_server";
        format_on_save = "on";
      };
      # Rust
      Rust = {
        tab_size = 4;
        formatter = "language_server";
        format_on_save = "on";
      };
      # TypeScript/JavaScript
      TypeScript = {
        tab_size = 2;
        formatter = "prettier";
      };
      JavaScript = {
        tab_size = 2;
        formatter = "prettier";
      };
      # Nix
      Nix = {
        tab_size = 2;
        formatter.external = {
          command = "nixfmt";
          arguments = [];
        };
      };
      # Markdown
      Markdown = {
        soft_wrap = "editor_width";
        show_whitespaces = "none";
      };
    };

    # Language server settings
    lsp = {
      yaml-language-server = {
        settings = {
          yaml = {
            keyOrdering = false;
            schemaStore.enable = true;
            schemas = {
              kubernetes = "*.{yaml,yml}";
            };
            customTags = [
              "!reference sequence"
            ];
          };
        };
      };
    };

    # Inlay hints
    inlay_hints = {
      enabled = true;
      show_type_hints = true;
      show_parameter_hints = true;
    };

    # File associations
    file_types = {
      Dockerfile = ["Dockerfile*" "*.dockerfile"];
      YAML = ["*.yaml" "*.yml" "*.yaml.j2" "*.yml.j2"];
    };

    # Project panel
    project_panel = {
      dock = "left";
      file_icons = true;
      folder_icons = true;
      git_status = true;
    };

    # Collaboration
    collaboration_panel.dock = "right";

    # Telemetry
    telemetry = {
      metrics = false;
      diagnostics = false;
    };
  };

  # Zed extensions to install (run `zed extensions` to manage)
  # Note: Zed installs extensions via the UI, but here's the recommended list:
  # - terraform, dockerfile, nix, ansible, toml, yaml
  # - catppuccin (theme), one-dark-pro (theme)
  # - git-firefly (enhanced git integration)

  # =============================================
  # Alacritty Terminal Configuration
  # =============================================
  xdg.configFile."alacritty/alacritty.toml".text = ''
    # Alacritty - Modern GPU-accelerated terminal
    [general]
    live_config_reload = true

    [terminal.shell]
    program = "/run/current-system/sw/bin/fish"

    [env]
    TERM = "xterm-256color"

    # ─────────────────────────────────────────
    # Font Configuration
    # ─────────────────────────────────────────
    [font]
    size = 13.0

    [font.normal]
    family = "JetBrainsMono Nerd Font"
    style = "Regular"

    [font.bold]
    family = "JetBrainsMono Nerd Font"
    style = "Bold"

    [font.italic]
    family = "JetBrainsMono Nerd Font"
    style = "Italic"

    [font.bold_italic]
    family = "JetBrainsMono Nerd Font"
    style = "Bold Italic"

    # ─────────────────────────────────────────
    # Window Configuration
    # ─────────────────────────────────────────
    [window]
    decorations = "buttonless"
    opacity = 0.95
    blur = true
    dynamic_title = true
    option_as_alt = "Both"

    [window.padding]
    x = 10
    y = 10

    [window.dimensions]
    columns = 140
    lines = 35

    # ─────────────────────────────────────────
    # Scrolling
    # ─────────────────────────────────────────
    [scrolling]
    history = 10000
    multiplier = 3

    # ─────────────────────────────────────────
    # Cursor
    # ─────────────────────────────────────────
    [cursor]
    unfocused_hollow = true

    [cursor.style]
    shape = "Block"
    blinking = "Off"

    # ─────────────────────────────────────────
    # Selection
    # ─────────────────────────────────────────
    [selection]
    save_to_clipboard = true

    # ─────────────────────────────────────────
    # Colors (One Dark Theme)
    # ─────────────────────────────────────────
    [colors.primary]
    background = "#1e2127"
    foreground = "#abb2bf"

    [colors.cursor]
    text = "#1e2127"
    cursor = "#abb2bf"

    [colors.selection]
    text = "CellForeground"
    background = "#3e4451"

    [colors.normal]
    black   = "#1e2127"
    red     = "#e06c75"
    green   = "#98c379"
    yellow  = "#d19a66"
    blue    = "#61afef"
    magenta = "#c678dd"
    cyan    = "#56b6c2"
    white   = "#abb2bf"

    [colors.bright]
    black   = "#5c6370"
    red     = "#e06c75"
    green   = "#98c379"
    yellow  = "#d19a66"
    blue    = "#61afef"
    magenta = "#c678dd"
    cyan    = "#56b6c2"
    white   = "#ffffff"

    # ─────────────────────────────────────────
    # Key Bindings
    # ─────────────────────────────────────────
    [keyboard]
    bindings = [
      # Quick actions
      { key = "N", mods = "Command", action = "SpawnNewInstance" },
      { key = "K", mods = "Command", action = "ClearHistory" },
      { key = "F", mods = "Command|Shift", action = "ToggleFullscreen" },

      # Font size
      { key = "Plus", mods = "Command", action = "IncreaseFontSize" },
      { key = "Minus", mods = "Command", action = "DecreaseFontSize" },
      { key = "Key0", mods = "Command", action = "ResetFontSize" },
    ]
  '';

  # =============================================
  # VS Code / Cursor Terminal Configuration
  # =============================================
  home.activation.configureVSCodeFish = config.lib.dag.entryAfter ["writeBoundary"] ''
    update_settings() {
      local settings_file="$1"
      local settings_dir=$(dirname "$settings_file")

      mkdir -p "$settings_dir"

      if [ ! -f "$settings_file" ]; then
        echo '{}' > "$settings_file"
      fi

      ${pkgs.jq}/bin/jq '. + {
        "terminal.integrated.defaultProfile.osx": "fish",
        "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font",
        "terminal.integrated.fontSize": 13,
        "terminal.integrated.lineHeight": 1.2,
        "terminal.integrated.cursorBlinking": false,
        "terminal.integrated.profiles.osx": (."terminal.integrated.profiles.osx" // {}) + {
          "fish": {
            "path": "/run/current-system/sw/bin/fish"
          }
        },
        "editor.fontFamily": "JetBrainsMono Nerd Font, Menlo, Monaco, monospace",
        "editor.fontSize": 14,
        "editor.fontLigatures": true,
        "editor.renderWhitespace": "selection",
        "editor.formatOnSave": true,
        "editor.minimap.enabled": false,
        "workbench.colorTheme": "One Dark Pro",
        "workbench.iconTheme": "catppuccin-latte",
        "files.trimTrailingWhitespace": true,
        "files.insertFinalNewline": true
      }' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"

      echo "Updated settings in $settings_file"
    }

    update_settings "$HOME/Library/Application Support/Cursor/User/settings.json"
    update_settings "$HOME/Library/Application Support/Code/User/settings.json"
  '';
}
