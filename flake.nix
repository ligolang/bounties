{
  description = "Bounty website for LIGO";
  inputs.archivable.url = github:SuzanneSoy/archivable/9d01ce1a663bb3cde8e86ea0819dd24721a17bda;
  outputs = { self, nixpkgs, archivable }: {
    defaultPackage.x86_64-linux = self.packages.x86_64-linux.website;
    packages.x86_64-linux.website =
      let pkgs = import nixpkgs { system = "x86_64-linux"; }; in
      pkgs.stdenv.mkDerivation {
        name = "website";
        src = self;
        buildInputs = with pkgs; [pandoc kubo jq nodejs-slim];
        buildPhase = ''
          mkdir "$out"
          mkdir "$out/www"

          # TODO: make sure titles and page names don't contain HTML special characters

          template() {
            # usage: template TITLE CONTENTS_FILE PATH_TO_OUTPUT_WWW_ROOT RELATIVE_PATH_TO_OUTPUT_HTML
            cat template.html \
              | sed -e "/markdown-title-placeholder/a <title>$1</title>" \
                    -e '/markdown-title-placeholder/d' \
              | sed -e "/markdown-content-placeholder/r $2" \
                    -e '/markdown-content-placeholder/d' \
              | sed -e "s~placeholder-filepath~$4~g" \
              > "$3/$4"
          }

          for bounty in bounties/*.md; do
            name="$(basename "$bounty" .md)"
            template "LIGO Bounty $name" <(pandoc -f markdown -t html "$bounty") "$out/www/" "$name.html"
          done
          
          index_html_links() {
            printf '%s\n' "<ul>"
            for bounty in bounties/*.md; do
              name="$(basename "$bounty" .md)"
              printf '<li><a href="%s.html">%s</a></li>\n' "$name" "$name"
            done
            printf '%s\n' "</ul>"
          }
          template "LIGO Bounties" <(index_html_links) "$out/www/" "index.html"

          cp style.css sha256.js micro_ipfs.js "$out/www/"
          cp www-ipfsignore "$out/www/.ipfsignore"

          export HOME=.
          ipfs init
          ${archivable.packages.x86_64-linux.update-directory-hashes}/bin/update-directory-hashes "$out/www/" 'tez'
          printf 'ipfs://%s\n' "$(ipfs cid base32 "$(ipfs add --ignore-rules-path "$out/www/.ipfsignore" --pin=false --hidden -Qr "$out/www")")" > "$out/ipfs.url" 2>&1
        '';

        # Prevent automatic modification of files in the output.
        dontInstall = true;
        dontFixup = true;
        dontPatchELF = true;
        dontPatchShebangs = true;
      };
  };
}
