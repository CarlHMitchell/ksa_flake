{
  description = "Kitten Space Agency rocket engineering simulator game";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # Fixed-output derivation: exchanges a stored refresh token for a fresh access token, calls the signed-URL endpoint, and downloads the tarball.
    # The output is pinned by hash so it's only re-fetched when the version changes.
    # The token is embedded in the derivation at eval time; the FOD output is content-addressed so the build only runs once regardless of token rotation.
    # Usage: KSA_REFRESH_TOKEN=$(cat "${XDG_CONFIG_HOME:-~/.config}/ksa/refresh-token") nix build --impure
    #        (create "${XDG_CONFIG_HOME:-~/.config}/ksa/" and run `nix run .#get-token` once to obtain a refresh token)
    ksaTarball = pkgs.stdenvNoCC.mkDerivation {
      name = "ksa-tarball-2026.7.6.4939.tar.gz";

      nativeBuildInputs = [pkgs.curl pkgs.jq pkgs.cacert];

      KSA_REFRESH_TOKEN = builtins.getEnv "KSA_REFRESH_TOKEN";

      outputHash = "0mm4kw809xx9rq7hwljj8b6hmh54wa99gs9y7b4sfhpmw0b735sh";
      outputHashAlgo = "sha256";
      outputHashMode = "flat";

      buildCommand = ''
        # 1. Exchange the stored refresh token for a fresh access token
        if [ -z "$KSA_REFRESH_TOKEN" ]; then
          echo "KSA: KSA_REFRESH_TOKEN is empty — pass it via: KSA_REFRESH_TOKEN=\$(cat ~/.config/ksa/refresh-token) nix build --impure" >&2
          exit 1
        fi

        token_response=$(curl -fsSL \
          --data-urlencode "grant_type=refresh_token" \
          --data-urlencode "client_id=ahwoo-client" \
          --data-urlencode "refresh_token=$KSA_REFRESH_TOKEN" \
          'https://auth.ahwoo.com/realms/ahwoo/protocol/openid-connect/token')

        access_token=$(echo "$token_response" | jq -r '.access_token')

        if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
          echo "KSA: token refresh failed — run 'nix run .#get-token' to get a fresh refresh token" >&2
          exit 1
        fi

        # 2. Get the pre-signed download URL for the latest Linux build
        signed_url=$(curl -fsSL \
          -H "Authorization: Bearer $access_token" \
          'https://api.ahwoo.com/games/0197f25e-1171-7476-944d-fdf8091a8edc/download/latest/linux' \
          | jq -r '.signedUrl')

        if [ -z "$signed_url" ] || [ "$signed_url" = "null" ]; then
          echo "KSA: failed to get signed download URL" >&2
          exit 1
        fi

        # 3. Download the tarball
        curl -fsSL -o "$out" "$signed_url"
      '';
    };

    gameFiles = pkgs.stdenvNoCC.mkDerivation {
      pname = "kitten-space-agency-data";
      version = "2026.7.6.4939";

      src = ksaTarball;

      dontBuild = true;
      dontConfigure = true;
      dontFixup = true;
      dontUnpack = true;

      installPhase = ''
        mkdir -p $out/lib/ksa
        tar -xzf $src -C $out/lib/ksa --strip-components=1
        chmod +x $out/lib/ksa/KSA $out/lib/ksa/Brutal.Monitor.Subprocess
      '';
    };
  in {
    packages.${system} = {
      default = pkgs.buildFHSEnv {
        name = "ksa";

        targetPkgs = pkgs:
          with pkgs; [
            stdenv.cc.cc.lib
            vulkan-loader
            icu
            openssl
            zlib
            libX11
            libXrandr
            libXi
            libXcursor
            libXinerama
            libxcb
            wayland
            libxkbcommon
          ];

        runScript = pkgs.writeShellScript "ksa-launcher" ''
          cd ${gameFiles}/lib/ksa
          exec ./KSA "$@"
        '';

        meta = {
          description = "Kitten Space Agency rocket engineering simulator game";
          platforms = ["x86_64-linux"];
          mainProgram = "ksa";
        };
      };

      # Run once to get a refresh token, then:
      #   mkdir -p "${XDG_CONFIG_HOME:-~/.config}/ksa"
      #   nix run .#get-token > "${XDG_CONFIG_HOME:-~/.config}/ksa/refresh-token"
      get-token = pkgs.writeShellApplication {
        name = "ksa-get-token";
        runtimeInputs = [pkgs.jq pkgs.xdg-utils];
        text = ''
          echo "Opening https://ahwoo.com in your browser. Log in if needed." >&2
          xdg-open 'https://ahwoo.com/app/100000/kitten-space-agency' 2>/dev/null || true

          echo "" >&2
          echo "The Keycloak adapter holds tokens in memory, so use the Network tab:" >&2
          echo "" >&2
          echo "  1. Open DevTools (F12) → Network tab" >&2
          echo "  2. Check 'Preserve log' in Chrome or click the gear and then check "Persist Logs" in Firefox"" >&2
          echo "  3. Refresh the page (Ctrl+R)" >&2
          echo "  4. In the filter box type: token" >&2
          echo "  5. Click the POST request to auth.ahwoo.com/.../token" >&2
          echo "  6. Go to the Response tab and copy the value of \"refresh_token\"" >&2
          echo "" >&2
          echo "Paste the refresh_token value here and press Enter:" >&2

          read -r refresh_token
          refresh_token="''${refresh_token#\"}"
          refresh_token="''${refresh_token%\"}"

          if [ -z "$refresh_token" ]; then
            echo "No token provided." >&2
            exit 1
          fi

          # Validate it works before printing
          result=$(curl -fsSL \
            --data-urlencode "grant_type=refresh_token" \
            --data-urlencode "client_id=ahwoo-client" \
            --data-urlencode "refresh_token=$refresh_token" \
            'https://auth.ahwoo.com/realms/ahwoo/protocol/openid-connect/token')

          # Keycloak rotates refresh tokens on each use — save the NEW one from
          # the validation response, not the original (which is now invalidated).
          new_refresh_token=$(echo "$result" | jq -r '.refresh_token // empty')

          if [ -n "$new_refresh_token" ]; then
            echo "Token validated successfully." >&2
            printf '%s' "$new_refresh_token"
          else
            echo "Token validation failed:" >&2
            echo "$result" | jq . >&2
            exit 1
          fi
        '';
      };
    };
  };
}
