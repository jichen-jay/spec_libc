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
      };

      uvVersion = "0.5.5";

      src = pkgs.fetchFromGitHub {
        owner = "astral-sh";
        repo = "uv";
        rev = uvVersion;
        sha256 = "sha256-E0U6K+lvtIM9htpMpFN36JHA772LgTHaTCVGiTTlvQk=";
      };

      # Define the Debian FHS environment with necessary packages
      debianEnv = pkgs.buildFHSUserEnv {
        name = "debian-env";

        targetPkgs = pkgs: (with pkgs; [
          gcc
          glibc
          openssl
          zlib
          libgit2
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
          rustc
          cargo
        ]);

        profile = ''
          export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH
        '';

        runScript = ''
          bash
        '';
      };

      # Define the uvBuilder derivation
      uvBuilder = pkgs.stdenv.mkDerivation {
        pname = "uv";
        version = uvVersion;
        inherit src;

        nativeBuildInputs = [
          debianEnv
        ];
         
buildPhase = ''
  # Start the FHS environment
  ${debianEnv}/bin/debian-env -c '
    set -x
    export OPENSSL_NO_VENDOR=1
    export ZLIB_NO_VENDOR=1
    export LIBGIT2_SYS_USE_PKG_CONFIG=1

    # Copy the source code into the current directory
    cp -r ${src}/* .

    # Print the current directory and contents
    echo "Current directory inside debian-env: $(pwd)"
    ls -la

    # Build the uv binary and ensure output is captured
    # Use unbuffer to force line buffering
    unbuffer cargo build --release

    # Check if the build was successful
    if [ ! -f target/release/uv ]; then
      echo "Cargo build failed to produce target/release/uv"
      exit 1
    fi
  '
'';


        installPhase = ''
          # Copy the built binary to $out
          mkdir -p "$out"/usr/local/bin
          cp target/release/uv "$out"/usr/local/bin/
        '';
      };

      # Build the Docker image
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
      # Export the image as the default package
      packages.${system} = {
        default = uvImage;
      };

      defaultPackage.${system} = uvImage;
    };
}
