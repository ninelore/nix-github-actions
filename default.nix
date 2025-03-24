let
  inherit (builtins) attrValues mapAttrs attrNames;
  flatten = list: builtins.foldl' (acc: v: acc ++ v) [ ] list;

  self = {
    githubPlatforms = {
      "x86_64-linux" = "ubuntu-24.04";
      "x86_64-darwin" = "macos-13";
      "aarch64-darwin" = "macos-14";
      "aarch64-linux" = "ubuntu-24.04-arm";
    };

    # Return a GitHub Actions matrix from a package set shaped like
    # the Flake attribute packages/checks.
    mkGithubMatrix =
      {
        checks, # Takes an attrset shaped like { x86_64-linux = { hello = pkgs.hello; }; }
        attrPrefix ? "githubActions.checks",
        platforms ? self.githubPlatforms,
      }:
      let
        # Helper function to check if an attribute should be included
        shouldInclude =
          system: attr:
          let
            drv = checks.${system}.${attr};
            meta = drv.meta or { };
            platforms = meta.platforms or (attrNames self.githubPlatforms);
            redist = meta.license.redistributable or true;
          in
          builtins.elem system platforms && redist;
      in
      {
        inherit checks;
        matrix = {
          include = flatten (
            attrValues (
              mapAttrs (
                system: pkgs:
                builtins.filter (x: x != null) (
                  attrValues (
                    mapAttrs (
                      attrName: attrVal:
                      if shouldInclude system attrName then
                        {
                          name = attrName;
                          inherit system;
                          os = platforms.${system};
                          attr = (
                            if attrPrefix != "" then "${attrPrefix}.${system}.\"${attrName}\"" else "${system}.\"${attrName}\""
                          );
                        }
                      else
                        null
                    ) pkgs
                  )
                )
              ) checks
            )
          );
        };
      };
  };

in
self
