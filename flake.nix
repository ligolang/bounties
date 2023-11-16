{
  description = "Bounty website for LIGO";
  inputs.archivable.url = github:SuzanneSoy/archivable/main;
  outputs = { self, nixpkgs }: {
    defaultPackage.x86_64-linux = self.packages.x86_64-linux.website;
    packages.x86_64-linux.website =
      let pkgs = import nixpkgs { system = "x86_64-linux"; }; in
      pkgs.stdenv.mkDerivation {
        name = "website";
        src = self;
        buildInputs = with pkgs; [pandoc kubo];
        buildPhase = ''
          mkdir "$out"
          mkdir "$out/www"
          (
            cat header.html
            pandoc -f markdown -t html bounty.md
            cat footer.html
          ) > "$out/www/index.html"

          export HOME=.
          ipfs init
          ipfs cid base32 "$(ipfs add --ignore-rules-path www-ipfsignore --pin=false --hidden -Qr "$out/www")" > "$out/ipfs.url" 2>&1
        '';
#        installPhase = "";
      };
  };
}
