{
  description = "Obsrvr Flow SQLite Consumer (Source Distribution)";

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
          default = pkgs.stdenv.mkDerivation {
            pname = "flow-consumer-sqlite-src";
            version = "0.1.0";
            src = ./.;
            
            # No build needed, we're just packaging the source
            dontBuild = true;
            
            # Install the source files into the output
            installPhase = ''
              # Create the destination directory
              mkdir -p $out/src/github.com/withObsrvr/flow-consumer-sqlite
              
              # Copy all source code and Go module files
              cp -r ./* $out/src/github.com/withObsrvr/flow-consumer-sqlite/
              
              # Create a build script that the main program can use
              mkdir -p $out/bin
              cat > $out/bin/build-plugin.sh << 'EOF'
              #!/bin/sh
              set -e
              
              # Set up environment for building
              export CGO_ENABLED=1
              
              # Create plugins directory if it doesn't exist
              mkdir -p plugins
              
              # Build the plugin with the same Go version and dependencies as the main program
              echo "Building SQLite consumer plugin..."
              go build -buildmode=plugin -o plugins/flow-consumer-sqlite.so github.com/withObsrvr/flow-consumer-sqlite
              
              echo "Plugin built successfully: plugins/flow-consumer-sqlite.so"
              EOF
              
              # Make the script executable
              chmod +x $out/bin/build-plugin.sh
            '';
            
            meta = {
              description = "Source code for Obsrvr Flow SQLite Consumer Plugin";
              mainProgram = "build-plugin.sh";
            };
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

