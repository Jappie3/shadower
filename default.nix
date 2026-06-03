{
  lib,
  clangStdenv,
  rustPlatform,
  makeWrapper,
  pkg-config,
  rustfmt,
  cargo,
  rustc,
  fetchFromGitHub,
  runCommand,
  gn,
  ninja,
  removeReferencesTo,
  python3,
  fetchgit,
  linkFarm,
  fontconfig,
  llvmPackages,
}:
let
  cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
in
rustPlatform.buildRustPackage.override { stdenv = clangStdenv; } rec {
  pname = cargoToml.package.name;
  version = cargoToml.package.version;

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  buildInputs = [
    pkg-config
    fontconfig
    llvmPackages.libclang
    llvmPackages.libcxxClang
  ];
  checkInputs = [
    cargo
    rustc
  ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    rustfmt
    rustc
    cargo
    removeReferencesTo
    python3 # for skia :)
  ];

  SKIA_SOURCE_DIR =
    let
      repo = fetchFromGitHub {
        owner = "rust-skia";
        repo = "skia";
        # see rust-skia:skia/Cargo.toml#package.metadata skia
        rev = "m148-0.97.0";
        sha256 = "sha256-uFnYX6ZDg+cJwLyCe6IGB6M3aCyI/+q2aYP4JfHm544=";
      };
      # see DEPS in rust-skia/skia at m148-0.97.0
      # https://github.com/rust-skia/skia/blob/3f465e408337f13a543849ec70c767b2c5e6eeb3/DEPS
      externals = linkFarm "skia-externals" (
        lib.mapAttrsToList (name: value: {
          inherit name;
          path = fetchgit value;
        }) (lib.importJSON ./skia-externals.json)
      );
    in
    runCommand "source" { } ''
      cp -R ${repo} $out
      chmod -R +w $out
      ln -s ${externals} $out/third_party/externals
    '';

  SKIA_GN_COMMAND = "${gn}/bin/gn";
  SKIA_NINJA_COMMAND = "${ninja}/bin/ninja";

  doCheck = true;
  CARGO_BUILD_INCREMENTAL = "false";
  RUST_BACKTRACE = "full";

  postFixup = ''
    remove-references-to -t "$SKIA_SOURCE_DIR" \
      $out/bin/shadower
  '';

  disallowedReferences = [ SKIA_SOURCE_DIR ];

  meta = {
    description = "A simple CLI utility to add rounded borders, padding, and shadows to images.";
    homepage = "https://github.com/n3oney/shadower";
    license = with lib.licenses; [ gpl3 ];
    maintainers = [
      {
        email = "neo@neoney.dev";
        github = "n3oney";
        githubId = 30625554;
        name = "Michał Minarowski";
      }
    ];
    mainProgram = "shadower";
  };
}
