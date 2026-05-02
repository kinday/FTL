{
  description = "Pi-hole";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          devShells.${system}.default = pkgs.mkShell {
            packages = [ pkgs.neovim ];
          };
          packages.${system}.default = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "pihole-ftl";
            version = "6.2.3";

            src = ./.;

            patches = [
              # https://github.com/pi-hole/FTL/pull/2610: Fix authentication redirect when webhome is /
              ./disable-redirect-root.patch
            ];

            nativeBuildInputs = with pkgs; [
              cmake
              xxd
            ];

            buildInputs = with pkgs; [
              gmp
              libidn2
              libunistring
              mbedtls
              ncurses
              nettle
              readline
            ];

            cmakeFlags = [
              (pkgs.lib.cmakeBool "STATIC" pkgs.stdenv.hostPlatform.isStatic)
            ];

            postPatch = ''
              substituteInPlace src/version.c.in \
                --replace-quiet "@GIT_VERSION@" "v${finalAttrs.version}" \
                --replace-quiet "@GIT_DATE@" "1970-01-01" \
                --replace-quiet "@GIT_BRANCH@" "master" \
                --replace-quiet "@GIT_TAG@" "v${finalAttrs.version}" \
                --replace-quiet "@GIT_HASH@" "builtfromreleasetarball"

              # Remove hard-coded absolute path to the pihole script, rely on it being provided by $PATH
              # Use execvp instead of execv so PATH is followed
              substituteInPlace src/api/action.c \
                --replace-fail "/usr/local/bin/pihole" "pihole" \
                --replace-fail "execv" "execvp"

              substituteInPlace src/database/network-table.c \
                --replace-fail "ip neigh show" "${pkgs.lib.getExe' pkgs.iproute2 "ip"} neigh show" \
                --replace-fail "ip address show" "${pkgs.lib.getExe' pkgs.iproute2 "ip"} address show"
            '';

            installPhase = ''
              runHook preInstall

              install -Dm 555 -t $out/bin pihole-FTL

              runHook postInstall
            '';

            passthru = {
              settingsTemplate = ./pihole.toml;
              tests = pkgs.nixosTests.pihole-ftl;
            };

            meta = {
              description = "Pi-hole FTL engine";
              homepage = "https://github.com/pi-hole/FTL";
              changelog = "https://github.com/pi-hole/FTL/releases/tag/v${finalAttrs.version}";
              license = pkgs.lib.licenses.eupl12;
              maintainers = with pkgs.lib.maintainers; [ averyvigolo ];
              platforms = pkgs.lib.platforms.linux;
              mainProgram = "pihole-FTL";
            };
          });
        };
    };
}
