{
  description = "Docker image with dynamically linked uv binary using Nix and Debian glibc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            debianPkgs = prev.pkgs.buildFHSUserEnv {
              name = "debian-env";
              targetPkgs = pkgs: (with pkgs; [
                gcc
                glibc
                glibc.dev
                glibc.static
                openssl
                openssl.dev
                zlib
                zlib.dev
                libgit2
                libgit2.dev
pkg-config

                python3
                gnumake
                bash
                coreutils
                binutils
                findutils
                curl
                wget
                xz
                which
              ]);
              multiPkgs = null;
              profile = ''
                export PATH=/usr/bin:/bin:/usr/sbin:/sbin
              '';
runScript = ''


                exec bash
'';


            };
          })
        ];
      };

      debianEnv = pkgs.debianPkgs;

      uvVersion = "0.5.5";

      src = pkgs.fetchFromGitHub {
        owner = "astral-sh";
        repo = "uv";
        rev = uvVersion;
        sha256 = "sha256-E0U6K+lvtIM9htpMpFN36JHA772LgTHaTCVGiTTlvQk=";
      };

      uvBuilder = pkgs.stdenv.mkDerivation {
        pname = "uv";
        version = uvVersion;
        inherit src;

        nativeBuildInputs = [
          debianEnv
        ];

        # We need to make the FHS environment visible in the build
        buildCommand = ''
          # Start the FHS environment
          ${debianEnv}/bin/debian-env -c "
            set -e
            export OPENSSL_NO_VENDOR=1
            export ZLIB_NO_VENDOR=1
            export LIBGIT2_SYS_USE_PKG_CONFIG=1

            # Change to the source directory
            cd $PWD

            # Build the uv binary
            cargo build --release

            # Install the uv binary
            mkdir -p $out/usr/local/bin
            cp target/release/uv $out/usr/local/bin/
          "
        '';
      };

      uvImage = pkgs.dockerTools.buildImage {
        name = "uv";
        tag = uvVersion;

        fromImage = "debian:bookworm-slim";

        config = {
          Entrypoint = [ "/usr/local/bin/uv" ];
          Cmd = [ ];
          WorkingDir = "/";
        };

        runAsRoot = ''
          apt-get update
          apt-get install -y libssl3 libgit2-1.3 zlib1g
          rm -rf /var/lib/apt/lists/*
        '';

        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [ uvBuilder ];
          pathsToLink = [ "/usr/local/bin" ];
        };
      };
    in
    {
      packages.${system} = {
        default = uvImage;
      };

      defaultPackage.${system} = uvImage;
    };
}
