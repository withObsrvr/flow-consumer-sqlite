{
  description = "Obsrvr Flow SQLite Consumer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = pkgs.buildGoModule {
            pname = "flow-consumer-sqlite";
            version = "0.1.0";
            src = ./.;
            # Hash calculated by Nix for go dependencies
            vendorHash = "sha256-0BiflEL31zzdd8veUNJqAroFdc8nRmfrCBEDa7KEIsw=";
            
            # Enable CGO for SQLite
            env = {
              CGO_ENABLED = "1";
            };
            
            # Build as a shared library/plugin
            buildPhase = ''
              runHook preBuild
              go build -buildmode=plugin -o flow-consumer-sqlite.so .
              runHook postBuild
            '';

            # Custom install phase for the plugin
            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib
              cp flow-consumer-sqlite.so $out/lib/
              runHook postInstall
            '';
            
            # Add SQLite library as a build dependency
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.sqlite ];
            
            # Explicitly use mod mode without vendor
            buildFlags = ["-mod=mod"];
          };
        };

        devShell = pkgs.mkShell {
          buildInputs = [ 
            pkgs.go_1_23 
            pkgs.sqlite
            pkgs.pkg-config
          ];
          # Enable CGO in the development shell too
          env = {
            CGO_ENABLED = "1";
          };
        };
      }
    );
}

