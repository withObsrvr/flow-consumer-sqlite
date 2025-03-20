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
        
        # Get the go package from gomod2nix
        goEnv = pkgs.mkGoEnv { modules = ./gomod2nix.toml; };
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "flow-consumer-sqlite";
            version = "0.1.0";
            src = ./.;
            
            # Add build dependencies
            nativeBuildInputs = [ 
              pkgs.pkg-config 
              pkgs.go_1_23
              goEnv
            ];
            buildInputs = [ pkgs.sqlite ];
            
            # Enable CGO for SQLite
            CGO_ENABLED = "1";
            
            # Simple build phase - build the plugin
            buildPhase = ''
              echo "Building plugin using gomod2nix..."
              go build -buildmode=plugin -o flow-consumer-sqlite.so .
            '';
            
            # Install phase - put the plugin where it should go
            installPhase = ''
              mkdir -p $out/lib
              cp flow-consumer-sqlite.so $out/lib/
              
              # Also copy metadata
              mkdir -p $out/share
              cp go.mod go.sum $out/share/
            '';
          };
        };

        # Provide the gomod2nix tool as a runnable app
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
          
          # Remind about gomod2nix usage
          shellHook = ''
            echo "Use 'nix run .#gomod2nix' to update dependency information"
          '';
        };
      }
    );
}

