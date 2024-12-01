{
  description = "Minimal Docker image with dynamically linked uv binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
    let
      system = "x86_64-linux";
      overlays = [ rust-overlay.overlays.default ];
      pkgs = import nixpkgs { inherit system overlays; };

      uvVersion = "0.5.5";
      src = pkgs.fetchFromGitHub {
        owner = "astral-sh";
        repo = "uv";
        rev = uvVersion;
        sha256 = "sha256-E0U6K+lvtIM9htpMpFN36JHA772LgTHaTCVGiTTlvQk=";
      };

      uvBinary = pkgs.rustPlatform.buildRustPackage rec {
        pname = "uv";
        version = uvVersion;
        inherit src;

        fetchCargoVendor = true;
        useFetchCargoVendor = true;
        cargoHash = "sha256-WbA0/HojU/E2ccAvV2sv9EAXLqcb+99LFHxddcYFZFw=";

        nativeBuildInputs = with pkgs; [
          pkg-config
          openssl
          zlib
          libgit2
        ];

        buildInputs = with pkgs; [
          openssl
          zlib
          libgit2
        ];

        doCheck = false;

        buildPhase = ''
          export OPENSSL_NO_VENDOR=1
          export OPENSSL_DIR=${pkgs.openssl.dev}
          export ZLIB_NO_VENDOR=1
          export ZLIB_DIR=${pkgs.zlib.dev}
          export LIBGIT2_SYS_USE_PKG_CONFIG=1
          cargo build --release --frozen
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp target/release/uv $out/bin/
        '';
      };

      uvMinimal = pkgs.stdenv.mkDerivation {
        name = "uv-minimal";

        nativeBuildInputs = [ pkgs.patchelf ];

        buildPhase = ''
          mkdir -p $out/bin
          cp ${uvBinary}/bin/uv $out/bin/

          # List of required libraries
          libs="$(ldd $out/bin/uv | grep '=> /nix/store' | awk '{print $3}')"

          mkdir -p $out/lib

          for lib in $libs; do
            cp $lib $out/lib/
          done

          # Fix the RPATH of the binary to find the libs in /lib
          patchelf --set-rpath /lib $out/bin/uv

          # Similarly, fix the RPATH of any copied libraries if necessary
          for lib in $out/lib/*; do
            patchelf --shrink-rpath $lib
          done

          # Strip binaries to reduce size
          strip $out/bin/uv
          strip $out/lib/*
        '';

        installPhase = ''
          true
        '';
      };

      uvImage = pkgs.dockerTools.buildImage {
        name = "uv";
        tag = uvVersion;

        fromImage = "scratch";

        config = {
          Cmd = [ "/bin/uv" ];
          WorkingDir = "/";
          Entrypoint = null;
        };

        contents = [ uvMinimal ];
      };
    in
    {
      packages.${system} = {
        default = uvImage;
      };
    };
}
