{
  description = "Obsrvr Flow SQLite Consumer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gomod2nix.url = "github:tweag/gomod2nix";
    gomod2nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, gomod2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ gomod2nix.overlays.default ];
        };
      in
      {
        packages = {
          default = pkgs.buildGoApplication {
            pname = "flow-consumer-sqlite";
            version = "0.1.0";
            src = ./.;
            
            # Use gomod2nix modules file
            modules = ./gomod2nix.toml;
            
            # Enable CGO for SQLite
            CGO_ENABLED = "1";
            
            # Build as a shared library/plugin
            postBuild = ''
              go build -buildmode=plugin -o flow-consumer-sqlite.so .
            '';

            # Custom install phase for the plugin
            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib
              cp flow-consumer-sqlite.so $out/lib/
              # Also install a copy of go.mod for future reference
              mkdir -p $out/share
              cp go.mod go.sum $out/share/
              runHook postInstall
            '';
            
            # Add SQLite library as a build dependency
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.sqlite ];
          };
        };

        # Required utility to generate gomod2nix.toml
        apps.gomod2nix = {
          type = "app";
          program = "${gomod2nix.packages.${system}.default}/bin/gomod2nix";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ 
            go_1_23
            sqlite
            pkg-config
            gomod2nix.packages.${system}.default
          ];
          
          # Enable CGO in the development shell
          env = {
            CGO_ENABLED = "1";
          };
          
          # Helper to remind about gomod2nix
          shellHook = ''
            echo "Use 'nix run .#gomod2nix' to generate/update the gomod2nix.toml file"
          '';
        };
      }
    );
}

