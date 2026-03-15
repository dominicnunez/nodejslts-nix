{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  xz,
}:

let
  versionInfo = lib.importJSON ./version.json;
  version = versionInfo.version;
  assets = versionInfo.assets;
  hashes = versionInfo.hashes;

  system = stdenv.hostPlatform.system;
  asset = assets.${system} or (throw "Unsupported system: ${system}");
  hash = hashes.${system} or (throw "Missing hash for system: ${system}");
in
stdenv.mkDerivation {
  pname = "nodejs-lts";
  inherit version;

  src = fetchurl {
    url = "https://nodejs.org/dist/v${version}/${asset}";
    inherit hash;
  };

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      autoPatchelfHook
    ]
    ++ [
      xz
    ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    tar -xJf "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    root_dir="$(echo node-v${version}-*)"
    mkdir -p "$out"
    cp -R "$root_dir"/. "$out"/
    chmod -R u+w "$out"

    rm -f "$out/bin/npm" "$out/bin/npx" "$out/bin/corepack"

    cat > "$out/bin/npm" <<EOF
    #!${stdenv.shell}
    exec "$out/bin/node" "$out/lib/node_modules/npm/bin/npm-cli.js" "\$@"
    EOF
    chmod +x "$out/bin/npm"

    cat > "$out/bin/npx" <<EOF
    #!${stdenv.shell}
    exec "$out/bin/node" "$out/lib/node_modules/npm/bin/npx-cli.js" "\$@"
    EOF
    chmod +x "$out/bin/npx"

    cat > "$out/bin/corepack" <<EOF
    #!${stdenv.shell}
    exec "$out/bin/node" "$out/lib/node_modules/corepack/dist/corepack.js" "\$@"
    EOF
    chmod +x "$out/bin/corepack"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    actual_version="$($out/bin/node --version)"
    test "$actual_version" = "v${version}"
    $out/bin/npm --version >/dev/null
    $out/bin/corepack --version >/dev/null
  '';

  meta = with lib; {
    description = "Official Node.js LTS binaries packaged as a reusable Nix flake";
    homepage = "https://nodejs.org";
    license = licenses.mit;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames assets;
    mainProgram = "node";
  };
}
