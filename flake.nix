{
  description = "Reusable Nix flake for official Node.js LTS binaries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      versionInfo = builtins.fromJSON (builtins.readFile ./version.json);
      exactAttrName = versionInfo.attr;
      overlay = final: prev: {
        nodejsLts = final.callPackage ./package.nix { };
        "${exactAttrName}" = final.nodejsLts;
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
        package = pkgs.nodejsLts;
      in
      {
        packages = {
          default = package;
          nodejsLts = package;
          "${exactAttrName}" = package;
        };

        apps = {
          default = {
            type = "app";
            program = "${package}/bin/node";
            meta.description = "Run Node.js LTS";
          };
          node = self.apps.${system}.default;
        };

        formatter = pkgs.nixpkgs-fmt;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            curl
            gh
            nixpkgs-fmt
            python3
          ];
        };

        checks = {
          build = package;
          node-version = pkgs.runCommand "node-version-check" { } ''
            actual="$(${package}/bin/node --version)"
            test "$actual" = "v${versionInfo.version}"
            touch "$out"
          '';
          npm-version = pkgs.runCommand "npm-version-check" { } ''
            ${package}/bin/npm --version >/dev/null
            touch "$out"
          '';
          corepack-version = pkgs.runCommand "corepack-version-check" { } ''
            ${package}/bin/corepack --version >/dev/null
            touch "$out"
          '';
          exact-attr = pkgs.runCommand "exact-attr-check" { } ''
            test "${package}" = "${pkgs.${exactAttrName}}"
            touch "$out"
          '';
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}

