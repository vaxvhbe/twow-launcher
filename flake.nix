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
        version = "2025-08-27";

      in {
        packages = {
          default = pkgs.appimageTools.wrapType2 rec {
            inherit pname version;
            name = pname;

            src = pkgs.fetchurl {
              url = "https://turtle-eu.b-cdn.net/client/9BEF2C29BE14CF2C26030B086DFC854DB56096DDEAABE31D33BFC6B131EC5529/TurtleWoW.AppImage";
              hash = "sha256-/4qRkc6m+F0djc0YoIfMZxwHaZsrowkyc9O6jS5fUEk=";
            };

            # HACK: The AppImage contains absolute paths to /lib for Wayland.
            # We preload libraries from the Nix store to work around this issue.
            extraPkgs = pkgs: with pkgs; [
              # Wayland dependencies
              wayland
              libGL
              libglvnd

              # Audio
              libpulseaudio
              alsa-lib

              # Common game dependencies
              xorg.libX11
              xorg.libXcursor
              xorg.libXrandr
              xorg.libXi
              mesa

              # Fonts
              freetype
              fontconfig
            ];

            extraInstallCommands =
              let
                waylandClient = "${lib.getLib pkgs.wayland}/lib/libwayland-client.so.0";
                waylandCursor = "${lib.getLib pkgs.wayland}/lib/libwayland-cursor.so.0";
                preload = lib.concatStringsSep ":" [ waylandClient waylandCursor ];
              in ''
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

                # Wrapper with LD_PRELOAD for Wayland
                mv "$out/bin/${pname}" "$out/bin/.${pname}-unwrapped"

                makeWrapper "$out/bin/.${pname}-unwrapped" "$out/bin/${pname}" \
                  --prefix LD_PRELOAD : '${preload}' \
                  --set-default WAYLAND_DISPLAY "wayland-0" \
                  --set-default XDG_SESSION_TYPE "wayland"
              '';

            # Required for makeWrapper
            nativeBuildInputs = [ pkgs.makeWrapper ];

            meta = with lib; {
              description = "Turtle WoW - Classic World of Warcraft (1.12.1) private server client";
              homepage = "https://turtle-wow.org";
              license = licenses.unfree;
              platforms = [ "x86_64-linux" ];
              maintainers = [ ];
              mainProgram = pname;
            };
          };
        };

        # Alias for easier usage
        defaultPackage = self.packages.${system}.default;

        # For local testing: nix develop
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.nixpkgs-fmt ];
          shellHook = ''
            echo "🐢 Turtle WoW development environment"
            echo "Build: nix build"
            echo "Run: nix run"
          '';
        };
      }
    ) // {
      # Information for NixOS modules
      nixosModules.default = { config, lib, pkgs, ... }: {
        options.programs.turtle-wow.enable = lib.mkEnableOption "Turtle WoW client";

        config = lib.mkIf config.programs.turtle-wow.enable {
          environment.systemPackages = [ self.packages.${pkgs.system}.default ];
        };
      };
    };
}
