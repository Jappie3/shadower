{
  description = "A simple CLI utility to add rounded borders, padding, and shadows to images.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      inherit (nixpkgs) lib;
      cargoToml = fromTOML (builtins.readFile ./Cargo.toml);
      forAllSystems =
        f: lib.genAttrs lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        "${cargoToml.package.name}" = pkgs.callPackage ./. { };
        default = pkgs.callPackage ./. { };
      });

      checks = forAllSystems (pkgs: {
        format =
          pkgs.runCommand "check-format"
            {
              buildInputs = with pkgs; [
                rustfmt
                cargo
              ];
            }
            ''
              ${pkgs.rustfmt}/bin/cargo-fmt fmt --manifest-path ${./.}/Cargo.toml -- --check
              ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
              touch $out # it worked!
            '';
        "${cargoToml.package.name}" = pkgs.callPackage ./. { };
      });

      devShell = forAllSystems (
        pkgs:
        pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; } {
          inputsFrom = [
            self.packages.${pkgs.stdenv.hostPlatform.system}."${cargoToml.package.name}"
          ];
          NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.clangStdenv.cc.cc
            pkgs.openssl
            #pkgs.skia
          ];

          NIX_LD = "/run/current-system/sw/share/nix-ld/lib/ld.so";
          SKIA_NINJA_COMMAND = "${pkgs.ninja}/bin/ninja";
          SKIA_GN_COMMAND = "${pkgs.gn}/bin/gn";

          buildInputs = with pkgs; [
            rustfmt
            rust-analyzer
            nixpkgs-fmt
            ninja
            clang
          ];
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
        }
      );
    };
}
