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
            
            # Use the previously verified hash for dependencies
            vendorHash = "sha256-0BiflEL31zzdd8veUNJqAroFdc8nRmfrCBEDa7KEIsw=";
            
            # Don't build the main package (since it's a plugin)
            subPackages = [];
            
            # Set environment variables
            env = {
              CGO_ENABLED = "1";
            };
            
            # Add SQLite library as a build dependency
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.sqlite ];
            
            # Override the build phase to create a plugin
            overrideModAttrs = old: {
              preBuild = ''
                # Make sure we have a clean build
                rm -f *.so
              '';
            };
            
            # Custom build phase for the plugin
            buildPhase = ''
              runHook preBuild
              
              echo "Building plugin..."
              go build -buildmode=plugin -o flow-consumer-sqlite.so .
              
              runHook postBuild
            '';
            
            # Custom install phase
            installPhase = ''
              runHook preInstall
              
              mkdir -p $out/lib
              cp flow-consumer-sqlite.so $out/lib/
              
              # Also install metadata
              mkdir -p $out/share
              cp go.mod go.sum $out/share/
              
              runHook postInstall
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ 
            go_1_23
            sqlite
            pkg-config
          ];
          
          # Enable CGO in the development shell
          env = {
            CGO_ENABLED = "1";
          };
        };
      }
    );
}

