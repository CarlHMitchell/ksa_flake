# Flake for Kitten Space Agency

Kitten Space Agency (KSA) provides generic Linux builds, but not a way to run them on NixOS. This flake allows the use of KSA on NixOS.

## Usage

Ensure flakes are enabled on your system.

### Getting your refresh token

As of 2026-07, the KSA website uses Keycloak tokens to require a user account to download KSA. To get your token, create `"${XDG_CONFIG_HOME:-~/.config}/ksa/"` and run `nix run .#get-token`.

### Installing

To build (download and install) requires access to the token, and will leave that token in the Nix store. This unfortunately means the build isn't pure.

`KSA_REFRESH_TOKEN=$(cat "${XDG_CONFIG_HOME:-~/.config}/ksa/refresh-token") nix build --impure`

### Running

`nix run`

## LICENSE

© C.H. Mitchell 2026

Released under Mozilla Public License version 2, see LICENSE.
