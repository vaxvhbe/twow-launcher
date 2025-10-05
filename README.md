# Turtle WoW Launcher

A Nix flake for running the Turtle WoW client.

## Overview

This flake packages the Turtle WoW AppImage as a Nix derivation with proper Wayland support and all necessary dependencies.

## Features

- **AppImage packaging**: Wraps the official Turtle WoW AppImage
- **Wayland support**: Includes LD_PRELOAD workaround for Wayland compatibility
- **Desktop integration**: Provides a `.desktop` file for system menu integration
- **Complete dependencies**: Bundles all required libraries (Wayland, OpenGL, audio, X11, fonts)

## Installation

### Using Nix Flakes

Run directly without installing:
```bash
nix run github:vaxvhbe/twow-launcher
```

Install to your profile:
```bash
nix profile install github:vaxvhbe/twow-launcher
```

Build locally:
```bash
nix build
./result/bin/turtle-wow
```

### NixOS System Integration

Add to your `configuration.nix`:
```nix
{
  inputs.turtle-wow.url = "github:vaxvhbe/twow-launcher";

  # ...

  programs.turtle-wow.enable = true;
}
```

## Development

Enter the development shell:
```bash
nix develop
```

This provides:
- `nixpkgs-fmt` for formatting
- Build and run commands

## Technical Details

### Package Information
- **Version**: 2025-08-27
- **Source**: Official Turtle WoW AppImage (EU CDN)
- **Hash**: Verified SHA-256 checksum

### Dependencies
The package includes:
- **Wayland**: Full Wayland protocol support
- **Graphics**: OpenGL, Mesa, libglvnd
- **Audio**: PulseAudio, ALSA
- **Display**: X11 libraries (for fallback compatibility)
- **Fonts**: FreeType, Fontconfig

### Wayland Workaround
The AppImage contains absolute paths to `/lib` for Wayland libraries. This is resolved by:
1. Preloading Nix store Wayland libraries via `LD_PRELOAD`
2. Setting appropriate Wayland environment variables
3. Wrapping the binary with `makeWrapper`

## License

The Turtle WoW client is proprietary/unfree software. See [turtle-wow.org](https://turtle-wow.org) for terms of service.

## Platform Support

- **Supported**: x86_64-linux
- **Tested on**: NixOS with Wayland compositors

## Links

- [Turtle WoW Official Website](https://turtle-wow.org)
- [Nix Flakes Documentation](https://nixos.wiki/wiki/Flakes)
