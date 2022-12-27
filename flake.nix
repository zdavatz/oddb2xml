{
  description = "Reproducible setup for n8henrie.com via GitHub Pages";
  inputs = {
    # ruby 2.7.3
    # https://pages.github.com/versions/
    # https://lazamar.co.uk/nix-versions/?channel=nixpkgs-unstable&package=ruby
    nixpkgs.url = "https://github.com/NixOS/nixpkgs/archive/860b56be91fb874d48e23a950815969a7b832fbc.tar.gz";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      gems = pkgs.bundlerEnv {
        ruby = pkgs.ruby;
        name = "n8henrie.com";
        gemdir = ./.;

        gemConfig.nokogiri = attrs: {
          buildInputs = [ pkgs.zlib ];
        };
      };
    in
    {
      devShell.${system} =
        let
          pkgs = import nixpkgs { inherit system; };
        in
        with pkgs;
        mkShell {
          buildInputs = [
            bundix
            gems
            libffi
            pkgconfig
            ruby
          ];
          shellHook = ''
            export LANG="en_US.UTF-8"
            make develop
          '';
        };
    };
}
