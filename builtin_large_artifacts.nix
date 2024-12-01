{
  description = "Container with uv using Nix shell and scratch image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      lib = pkgs.lib;

      uvVersion = "0.5.5";
      src = pkgs.fetchFromGitHub {
        owner = "astral-sh";
        repo = "uv";
        rev = uvVersion;
        sha256 = "sha256-E0U6K+lvtIM9htpMpFN36JHA772LgTHaTCVGiTTlvQk=";
      };

      uvNativeBuildInputs = with pkgs; [
        pkg-config
        openssl
        zlib
        libgit2
      ];

      uvBinaryGlibc = pkgs.rustPlatform.buildRustPackage rec {
        pname = "uv";
        version = uvVersion;
        inherit src;

        fetchCargoVendor = true;
        useFetchCargoVendor = true;
        cargoHash = "sha256-WbA0/HojU/E2ccAvV2sv9EAXLqcb+99LFHxddcYFZFw="; # Replace with actual hash after initial build

        nativeBuildInputs = uvNativeBuildInputs;
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
          export RUSTFLAGS="-C codegen-units=1"
          cargo build --release --frozen
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp target/release/uv $out/bin/
        '';
      };

      uvImageGlibc = pkgs.dockerTools.buildImage {
        name = "uv-glibc-image";
        tag = uvVersion;
        created = "now";
        config = {
          Cmd = [ "uv" ];
          Entrypoint = null;
        };

        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          pathsToLink = [ "/bin" ];
          paths = [
            uvBinaryGlibc
            pkgs.glibcLocales
            pkgs.cacert
          ];
          postBuild = ''
            mkdir -p $out/lib
            cp -r ${pkgs.glibcLocales}/lib/* $out/lib/
            mkdir -p $out/etc/ssl/certs
            cp ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/
          '';
        };
      };
    in
    {
      packages.${system} = {
        default = uvImageGlibc;
      };
    };
}
