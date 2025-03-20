{ lib, buildGoApplication, gomod2nix, pkg-config, sqlite }:

buildGoApplication {
  pname = "flow-consumer-sqlite";
  version = "0.1.0";
  src = ../.;
  modules = ./gomod2nix.toml;
  
  # Enable CGO for SQLite
  CGO_ENABLED = "1";
  
  # Add SQLite library as a build dependency
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ sqlite ];
  
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
  
  # Skip tests during build as this is a plugin
  doCheck = false;
} 