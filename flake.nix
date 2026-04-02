{
  description = "Turtle WoW - Classic World of Warcraft private server client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        pname = "turtle-wow";
        version = "2026-04-02";

        appImageSrc = pkgs.fetchurl {
          url = "https://turtle-eu.b-cdn.net/client/F674FA93D4C94E59ED7E23E0CC2C550A3AB9CBABCD822094B0D9B6EC43E42AFA/TurtleWoW.AppImage";
          hash = "sha256-9nT6k9TJTlntfiPgzCxVCjq5y6vNgiCUsNm27EPkKvo=";
        };

        # Shared package lists
        commonTargetPkgs =
          pkgs: with pkgs; [
            # AppImage / Launcher dependencies
            fuse
            udev
            alsa-lib
            openssl
            zlib
            glib
            nss
            nspr
            atk
            at-spi2-atk
            dbus
            gdk-pixbuf
            pango
            cairo
            libx11
            libxcursor
            libxrandr
            libxi
            libxext
            libxrender
            libxfixes
            libxcomposite
            libxdamage
            libxtst
            libxscrnsaver
            libxkbcommon
            mesa
            libglvnd
            wayland
            libpulseaudio
            gtk3
            webkitgtk_4_1
            freetype
            fontconfig
            bzip2
            gsettings-desktop-schemas
            adwaita-icon-theme
            libthai
            libsecret
            libsoup_3
            glib-networking

            # JSON parsing tool
            jq

            # Wine for running WoW.exe
            wineWowPackages.stable
            winetricks
          ];

        commonMultiPkgs =
          pkgs: with pkgs; [
            alsa-lib
            libpulseaudio
            mesa
            libglvnd
            udev
            libx11
            libxcursor
            libxrandr
            libxi
            libxext
            libxrender
            freetype
            fontconfig
            openssl
            glib
            zlib
          ];

        fhsEnv = pkgs.buildFHSEnv {
          name = pname;

          targetPkgs = commonTargetPkgs;
          multiPkgs = commonMultiPkgs;

          runScript = pkgs.writeScript "turtle-wow-launcher" ''
            #!/bin/bash
            APPIMAGE_SRC="${appImageSrc}"
            INSTALL_DIR="$HOME/.cache/turtle-wow-install"

            # 1. Extract and setup if needed (re-extract on version change)
            VERSION_FILE="$INSTALL_DIR/.appimage-src"
            if [ ! -d "$INSTALL_DIR" ] || [ "$(cat "$VERSION_FILE" 2>/dev/null)" != "$APPIMAGE_SRC" ]; then
                echo "🐢 Extracting Turtle WoW..."
                rm -rf "$INSTALL_DIR"
                mkdir -p "$INSTALL_DIR"
                cd "$INSTALL_DIR"
                cp "$APPIMAGE_SRC" ./TurtleWoW.AppImage
                chmod +x ./TurtleWoW.AppImage
                ./TurtleWoW.AppImage --appimage-extract > /dev/null
                echo "$APPIMAGE_SRC" > "$VERSION_FILE"
            fi

            cd "$INSTALL_DIR/squashfs-root"

            # 2. Compatibility patches
            mkdir -p shared/lib
            ln -sf /lib/libbz2.so.1 shared/lib/libbz2.so.1.0
            ln -sf /lib64/ld-linux-x86-64.so.2 shared/lib/ld-linux-x86-64.so.2

            # Force wine symlinks in common locations inside FHS
            mkdir -p /usr/bin
            ln -sf $(which wine) /usr/bin/wine 2>/dev/null || true
            ln -sf $(which wine) /bin/wine 2>/dev/null || true

            # Prune bundled libraries that conflict with NixOS system libraries
            find . -name "libc.so.6" -delete
            find . -name "libstdc++.so.6" -delete
            find . -name "libgcc_s.so.1" -delete
            find . -name "libpthread.so.0" -delete
            find . -name "libdl.so.2" -delete
            find . -name "librt.so.1" -delete
            find . -name "libm.so.6" -delete
            find . -name "libgio-2.0.so.0" -delete
            find . -name "libglib-2.0.so.0" -delete
            find . -name "libgmodule-2.0.so.0" -delete
            find . -name "libgobject-2.0.so.0" -delete
            find . -name "libuuid.so.1" -delete
            find . -name "libmount.so.1" -delete
            find . -name "libblkid.so.1" -delete
            find . -name "ld-linux-x86-64.so.2" -not -path "./shared/lib/*" -delete
            find . -name "libresolv.so.2" -delete
            find . -name "libnss_*.so.2" -delete

            # 3. Environment variables
            export LD_LIBRARY_PATH="$PWD/shared/lib:$LD_LIBRARY_PATH"
            export XKB_CONFIG_ROOT="${pkgs.xkeyboard_config}/share/X11/xkb"
            export GIO_MODULE_DIR="${pkgs.glib-networking}/lib/gio/modules"
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS"
            export APPIMAGE_SILENT_INSTALL=1
            export WINEDLLOVERRIDES="mscoree,mshtml="
            export WEBKIT_EXEC_PATH="${pkgs.webkitgtk_4_1}/libexec/webkit2gtk-4.1"

            # 4. Install Icons & Desktop Entries (Self-Installing)
            mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
            mkdir -p "$HOME/.local/share/applications"

            # Icon
            if [ -f "turtle-wow.png" ]; then
                cp "turtle-wow.png" "$HOME/.local/share/icons/hicolor/256x256/apps/turtle-wow.png"
            elif [ -f ".DirIcon" ]; then
                cp ".DirIcon" "$HOME/.local/share/icons/hicolor/256x256/apps/turtle-wow.png"
            fi

            # Launcher Desktop File
            cat > "$HOME/.local/share/applications/turtle-wow.desktop" <<EOF
            [Desktop Entry]
            Type=Application
            Name=Turtle WoW Launcher
            Comment=Classic World of Warcraft private server client
            Exec=nix run "${builtins.toString self}#default"
            Icon=turtle-wow
            Categories=Game;
            Terminal=false
            EOF

            # Game Desktop File
            cat > "$HOME/.local/share/applications/turtle-wow-game.desktop" <<EOF
            [Desktop Entry]
            Type=Application
            Name=Turtle WoW (Game)
            Comment=Launch WoW directly via Wine
            Exec=nix run "${builtins.toString self}#game"
            Icon=turtle-wow
            Categories=Game;
            Terminal=false
            EOF

            # Force update desktop database
            update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

            echo "🐢 Starting Turtle WoW Launcher..."
            chmod +x bin/turtle-wow
            ./bin/turtle-wow "$@"
          '';
        };

        wineGameEnv = pkgs.buildFHSEnv {
          name = "turtle-wow-game";
          targetPkgs = commonTargetPkgs;
          multiPkgs = commonMultiPkgs;
          runScript = pkgs.writeScript "run-wow" ''
            #!/bin/bash

            PREFS_FILE="$HOME/.local/share/turtle-wow/preferences.json"
            GAME_DIR=""

            if [ -f "$PREFS_FILE" ]; then
                GAME_DIR=$(jq -r '.clientDir // empty' "$PREFS_FILE" 2>/dev/null)
            fi

            if [ -z "$GAME_DIR" ] || [ "$GAME_DIR" == "null" ]; then
                echo "Error: No client directory found in $PREFS_FILE"
                exit 1
            fi

            EXE="$GAME_DIR/WoW.exe"

            if [ ! -f "$EXE" ]; then
                echo "Error: WoW.exe not found at $EXE"
                exit 1
            fi

            echo "🍷 Starting WoW.exe with Wine..."
            cd "$GAME_DIR"
            export WINEDLLOVERRIDES="mscoree,mshtml="
            wine WoW.exe "$@"
          '';
        };
      in
      {
        packages.default = fhsEnv;
        packages.game = wineGameEnv;

        apps.default = flake-utils.lib.mkApp { drv = fhsEnv; };
        apps.game = flake-utils.lib.mkApp { drv = wineGameEnv; };

        formatter = pkgs.nixpkgs-fmt;
        devShells.default = pkgs.mkShell { buildInputs = [ pkgs.nixpkgs-fmt ]; };
      }
    )
    // {
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          options.programs.turtle-wow.enable = lib.mkEnableOption "Turtle WoW client";
          config = lib.mkIf config.programs.turtle-wow.enable {
            environment.systemPackages = [ self.packages.${pkgs.system}.default ];
          };
        };
    };
}
