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
            
            # Don't build the main program
            subPackages = [];
            
            # Enable CGO for SQLite
            env = {
              CGO_ENABLED = "1";
            };
            
            # Add SQLite as a dependency
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.sqlite ];
            
            # Override the build phase to only build the plugin
            buildPhase = ''
              runHook preBuild
              
              echo "Building plugin..."
              go build -buildmode=plugin -o flow-consumer-sqlite.so .
              
              runHook postBuild
            '';
            
            # Custom install phase for the plugin
            installPhase = ''
              runHook preInstall
              
              mkdir -p $out/lib
              cp flow-consumer-sqlite.so $out/lib/
              
              # Also copy metadata
              mkdir -p $out/share
              cp go.mod go.sum $out/share/
              
              runHook postInstall
            '';
          };
        };

        # Since this approach works, we don't need gomod2nix. But we can easily add a tool to update the vendorHash:
        apps.update-deps = {
          type = "app";
          program = toString (pkgs.writeShellScript "update-deps" ''
            echo "Updating dependencies hash..."
            echo "Set vendorHash = null and run 'nix build', then replace with new hash"
            echo "This workflow is simpler than using gomod2nix for plugins"
          '');
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

