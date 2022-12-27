# See https://nixos.wiki/wiki/Packaging/Ruby
# https://nixos.org/manual/nixpkgs/stable/#developing-with-ruby
with (import <nixpkgs> { });
let
  env = bundlerEnv {
    name = "oddb2xml-env";
    inherit ruby;
    gemdir = ./.;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in
stdenv.mkDerivation {
  name = "oddb2xml";
  buildInputs = [ env ruby bundix yarn ];
}
