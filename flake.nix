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
            
            # Don't build the default main package since we're making a plugin
            subPackages = [];
            
            # Set environment variables
            CGO_ENABLED = "1";
            
            # Add SQLite library as a build dependency
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.sqlite ];
            
            # The most important part - override the build command
            overrideModAttrs = _old: {
              buildPhase = ''
                mkdir -p $GOPATH/bin
              '';
            };
            
            # Skip the installPhase of buildGoApplication
            preInstall = "find . -name flow-consumer-sqlite -delete";
            
            # Custom build phase for the plugin (postBuild runs after main build but before install)
            postBuild = ''
              echo "Building plugin..."
              go build -buildmode=plugin -o flow-consumer-sqlite.so .
            '';
            
            # Custom install phase to properly install the plugin
            installPhase = ''
              mkdir -p $out/lib
              cp flow-consumer-sqlite.so $out/lib/
              
              # Also install metadata
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

