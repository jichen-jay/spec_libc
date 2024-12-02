{ pkgs ? import <nixpkgs> { }, lib ? pkgs.lib }:

let
  pv = "0.5.5";
  pname = "uv";

  src = pkgs.fetchFromGitHub {
    owner = "astral-sh";
    repo = "uv";
    rev = "${pv}";
    sha256 = "E0U6K+lvtIM9htpMpFN36JHA772LgTHaTCVGiTTlvQk=";
  };
in

pkgs.rustPlatform.buildRustPackage rec {
  inherit pname version;
  version = pv;

  src = src;

  cargoSha256 = "WbA0/HojU/E2ccAvV2sv9EAXLqcb+99LFHxddcYFZFw=";

  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
    openssl.dev
    zlib.dev
    libgit2.dev
    python3
  ];

  buildInputs = with pkgs; [
    openssl
    zlib
    libgit2
  ];

  # Environment variables to use system libraries
  OPENSSL_NO_VENDOR = "1";
  ZLIB_NO_VENDOR = "1";
  LIBGIT2_SYS_USE_PKG_CONFIG = "1";

  cargoBuildFlags = [
    "--release"
  ];

  buildPhase = ''
    export RUST_BACKTRACE=1
    export OPENSSL_NO_VENDOR=${OPENSSL_NO_VENDOR}
    export ZLIB_NO_VENDOR=${ZLIB_NO_VENDOR}
    export LIBGIT2_SYS_USE_PKG_CONFIG=${LIBGIT2_SYS_USE_PKG_CONFIG}

    cargo build --release --verbose

    if [ ! -f target/release/uv ]; then
      echo "Cargo build failed."
      exit 1
    fi
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp target/release/uv $out/bin/
  '';

  meta = with pkgs.lib; {
    description = "Extremely fast Python package installer and resolver, written in Rust";
    homepage = "https://github.com/astral-sh/uv";
    license = licenses.asl20;
    maintainers = with maintainers; [ GaetanLepage ];
    platforms = platforms.linux;
  };
}
