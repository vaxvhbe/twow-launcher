{
  description = "Turtle WoW - Classic World of Warcraft private server client";

  nixConfig = {
    extra-substituters = [ "https://cache.nixos.org" ];
    extra-trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        lib = pkgs.lib;

        pname = "turtle-wow";
        version = "2025-12-23";

        appImageSrc = pkgs.fetchurl {
          url = "https://eucdn.turtlecraft.gg/47BA21AEF6EF008C5852157A7C47A852D51EF9B3AF8AA74DD78677BF8F05A629/TurtleWoW.AppImage";
          hash = "sha256-R7ohrvbvAIxYUhV6fEeoUtUe+bOviqdN14Z3v48Fpik=";
        };

        fhsEnv = pkgs.buildFHSEnv {
          name = pname;

          targetPkgs = pkgs: with pkgs; [
            # Standard dependencies
            fuse udev alsa-lib openssl zlib glib nss nspr atk at-spi2-atk dbus
            gdk-pixbuf pango cairo xorg.libX11 xorg.libXcursor xorg.libXrandr
            xorg.libXi xorg.libXext xorg.libXrender xorg.libXfixes xorg.libXcomposite
            xorg.libXdamage xorg.libXtst xorg.libXScrnSaver libxkbcommon mesa
            libglvnd libGL wayland libpulseaudio gtk3 webkitgtk_4_1 freetype
            fontconfig bzip2 gsettings-desktop-schemas adwaita-icon-theme
            libthai libsecret libsoup_3 glib-networking
          ];

          runScript = pkgs.writeScript "turtle-wow-launcher" ''
            #!/bin/bash
            APPIMAGE_SRC="${appImageSrc}"
            INSTALL_DIR="$HOME/.cache/turtle-wow-install"

            # 1. Extract and setup if needed
            if [ ! -d "$INSTALL_DIR" ]; then
                echo "🐢 Extracting Turtle WoW..."
                mkdir -p "$INSTALL_DIR"
                cd "$INSTALL_DIR"
                cp "$APPIMAGE_SRC" ./TurtleWoW.AppImage
                chmod +x ./TurtleWoW.AppImage
                ./TurtleWoW.AppImage --appimage-extract > /dev/null
            fi

            cd "$INSTALL_DIR/squashfs-root"

            # 2. Compatibility patches
            mkdir -p shared/lib
            ln -sf /lib/libbz2.so.1 shared/lib/libbz2.so.1.0
            ln -sf /lib64/ld-linux-x86-64.so.2 shared/lib/ld-linux-x86-64.so.2

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

            # 3. Environment variables for GTK/Tauri
            export LD_LIBRARY_PATH="$PWD/shared/lib:$LD_LIBRARY_PATH"
            export XKB_CONFIG_ROOT="${pkgs.xkeyboard_config}/share/X11/xkb"
            export GIO_MODULE_DIR="${pkgs.glib-networking}/lib/gio/modules"
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS"
            export APPIMAGE_SILENT_INSTALL=1

            # 4. Launch
            chmod +x bin/turtle-wow
            ./bin/turtle-wow "$@"
          '';

          extraInstallCommands = ''
            # Create .desktop file for system integration
            mkdir -p $out/share/applications
            cat > $out/share/applications/${pname}.desktop <<EOF
            [Desktop Entry]
            Type=Application
            Name=Turtle WoW
            Comment=Classic World of Warcraft private server client
            Exec=${pname} %U
            Icon=${pname}
            Categories=Game;
            Terminal=false
            EOF
          '';
        };
      in
      {
        packages.default = fhsEnv;
        formatter = pkgs.nixpkgs-fmt;
        devShells.default = pkgs.mkShell { buildInputs = [ pkgs.nixpkgs-fmt ]; };
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }: {
        options.programs.turtle-wow.enable = lib.mkEnableOption "Turtle WoW client";
        config = lib.mkIf config.programs.turtle-wow.enable {
          environment.systemPackages = [ self.packages.${pkgs.system}.default ];
        };
      };
    };
}
