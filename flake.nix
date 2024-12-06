{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, }:
    flake-utils.lib.eachDefaultSystem (system:
    let 
      pkgs = import nixpkgs { inherit system; }; 
      buildInputs = with pkgs; [elixir]; 
    in {
        devShells.default = pkgs.mkShell {
          buildInputs = buildInputs; 
        };
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "banj-cli";
          version = "0.0.0";
          src = ./.;
          # run tests?
          doCheck=false;
          inherit buildInputs;
          buildPhase = ''
            mix deps.get
            mix escript.build
          '';
          installPhase = ''
            mkdir -p $out/bin
            mv banj $out/bin
          '';
        };
      });
}
