{
  description = "Docker image with dynamically linked uv binary using a prebuilt base image";

  inputs = {
    # Use Nixpkgs 22.11 with glibc 2.36
    nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
    let
      system = "x86_64-linux";
      overlays = [ rust-overlay.overlays.default ]; # Adjusted for Nixpkgs 22.11
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
          patchelf # Needed for patchelf in postInstall
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
          mkdir -p $out/usr/local/bin
          cp target/release/uv $out/usr/local/bin/
        '';

        postInstall = ''
          patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 \
            --set-rpath /lib/x86_64-linux-gnu $out/usr/local/bin/uv
        '';
      };

      uvImage = pkgs.dockerTools.buildImage {
        name = "uv";
        tag = uvVersion;

        fromImage = "debian:bookworm-slim";

        config = {
          Cmd = [ "/usr/local/bin/uv" ];
          WorkingDir = "/";
          Entrypoint = null;
        };


        runAsRoot = ''
          apt-get update
          apt-get install -y libssl3 libgit2-1.3 zlib1g
          rm -rf /var/lib/apt/lists/*
        '';

        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [ uvBinary ];
          pathsToLink = [ "/usr/local/bin" ];
        };
      };
    in
    {
      packages.${system} = {
        default = uvImage;
      };
    };
}
