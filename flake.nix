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
        
        # Import the generated dependencies
        goModules = pkgs.callPackage ./gomod2nix.toml { };
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "flow-consumer-sqlite";
            version = "0.1.0";
            src = ./.;
            
            # Add required build inputs
            nativeBuildInputs = [ 
              pkgs.pkg-config
              pkgs.go_1_23
            ];
            buildInputs = [ pkgs.sqlite ];
            
            # Set CGO environment
            CGO_ENABLED = "1";
            
            # Custom build phase for Go plugin
            buildPhase = ''
              # Set GOPATH for modules
              export GOPATH=${goModules}:$GOPATH
              
              # Build the plugin
              go build -buildmode=plugin -o flow-consumer-sqlite.so .
            '';
            
            # Install the plugin
            installPhase = ''
              mkdir -p $out/lib
              cp flow-consumer-sqlite.so $out/lib/
              
              # Install metadata
              mkdir -p $out/share
              cp go.mod go.sum $out/share/
            '';
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

