{
  description = "Kitten Space Agency";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      gameFiles = pkgs.stdenv.mkDerivation {
        pname = "kitten-space-agency-data";
        version = "2026.7.6.4939";
        # Temp: require user to git add this source file. Big, suboptimal.
        src = ./setup_ksa_v2026.7.6.4939.tar.gz;

        dontBuild = true;
        dontConfigure = true;
        dontFixup = true;

        installPhase = ''
          mkdir -p $out/lib/ksa
          cp -a . $out/lib/ksa/
          chmod +x $out/lib/ksa/KSA $out/lib/ksa/Brutal.Monitor.Subprocess
        '';
      };
    in {
      packages.${system}.default = pkgs.buildFHSEnv {
        name = "ksa";

        targetPkgs = pkgs: with pkgs; [
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
          description = "Kitten Space Agency rocket engineering simulator";
          platforms = [ "x86_64-linux" ];
          mainProgram = "ksa";
        };
      };
    };
}
