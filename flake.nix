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
            
            # Use the gomod2nix generated modules file
            modules = ./gomod2nix.toml;
            
            # Set empty main module to avoid building a main binary
            mainModule = "";
            
            # Skip regular Go program build for plugins
            buildPhase = "true";
            
            # Set environment variables
            hardeningDisable = [ "all" ];
            CGO_ENABLED = "1";
            
            # Add SQLite library as a build dependency
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.sqlite ];
            
            # Bypass the normal install phase
            dontInstall = true;
            
            # Build the plugin and "install" it
            preFixup = ''
              echo "Building plugin..."
              cd $GOPATH/src/${src.meta.package.goPackagePath}
              go build -buildmode=plugin -o flow-consumer-sqlite.so .
              
              # Create output directories and install
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

