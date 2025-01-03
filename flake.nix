{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs-helm-secrets.url = "github:NixOS/nixpkgs/eb4f8bd5bb4fba814205693346bf5aaf9d17dfb0"; # helm-secret 4.6.0 above failed on WSL
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };
  outputs =
    { nixpkgs, nixpkgs-helm-secrets, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # pkgs = nixpkgs.legacyPackages.${system};
        formatter = nixpkgs.legacyPackages."${system}".nixfmt;
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
              "terraform"
            ];
          };
        };

		pkgs-helm-secrets = import nixpkgs-helm-secrets {
          inherit system;
          config = {
            allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
              "vault"
            ];
          };
        };
        my-kubernetes-helm = with pkgs; wrapHelm kubernetes-helm {
          plugins = with pkgs.kubernetes-helmPlugins; [
            pkgs-helm-secrets.kubernetes-helmPlugins.helm-secrets  # Use pinned version
            helm-diff
            helm-s3
            helm-git
          ];
        };
        my-helmfile = pkgs.helmfile-wrapped.override {
          inherit (my-kubernetes-helm) pluginsDir;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "homelab tools";
          packages = with pkgs; [
            bashInteractive
            zsh
            ansible
            helmfile
            terraform
            my-kubernetes-helm
            my-helmfile
            kubectl
            kubectx
            kubetail
            kind
            nixpkgs-fmt
            scaleway-cli
            sops
          ];

		            shellHook = ''
					export SHELL=${pkgs.zsh}/bin/zsh
            exec zsh
          '';
        };
      }
    );
}
