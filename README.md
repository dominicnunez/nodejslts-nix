# nodejslts-nix

Reusable Nix flake for official Node.js LTS binaries.

It packages the upstream Node release archives directly and exposes both a
moving current-LTS package and an exact versioned package attr for downstream
pinning.

## What It Exposes

- `packages.<system>.default`
- `packages.<system>.nodejsLts`
- `packages.<system>.nodejs_v24_14_0`
- `apps.<system>.default`
- `overlays.default`

The exact-version attr updates when `version.json` changes.

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

Windows is intentionally out of scope for v1.

## Usage

Run Node directly:

```bash
nix run github:your-org/nodejslts-nix
```

Install the current LTS package:

```bash
nix profile add github:your-org/nodejslts-nix
```

Use the exact pinned version:

```bash
nix profile add github:your-org/nodejslts-nix#nodejs_v24_14_0
```

Use as a flake input:

```nix
{
  inputs.nodejslts-nix.url = "github:your-org/nodejslts-nix";

  outputs = { self, nixpkgs, nodejslts-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nodejslts-nix.overlays.default ];
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.nodejsLts ];
      };
    };
}
```

## Development

Enter the maintenance shell:

```bash
nix develop
```

Run the repo checks:

```bash
nix flake check
```

Check for a newer LTS release:

```bash
nix develop --command ./update.sh
```

Update to the latest LTS release:

```bash
nix develop --command ./update.sh --update
```

## Release Metadata

`version.json` is the source of truth for:

- the pinned Node version
- the LTS codename
- the exact package attr name
- the upstream asset name per platform
- the Nix fetch hash per platform

The update workflow regenerates `version.json` from the official Node release
index and `SHASUMS256.txt`.

## License

The flake code in this repository is MIT licensed. Node.js itself is packaged
from official upstream releases; see the upstream project for runtime licensing
details and notices.

