{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # pkgs = nixpkgs.legacyPackages.${system};
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfreePredicate = pkg: builtins.elem(nixpkgs.lib.getName pkg)[
              "terraform"
            ];
          };
        };

        my-kubernetes-helm = with pkgs; wrapHelm kubernetes-helm {
          plugins = with pkgs.kubernetes-helmPlugins; [
            helm-secrets
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
        formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
        devShells.default = pkgs.mkShell { 
          name = "homelab tools";
          packages = with pkgs; [
            bashInteractive
            ansible
            helmfile
            terraform
            my-kubernetes-helm
            my-helmfile
            kubectl
            kubectx
            kubetail
            kind
          ];
          # nativeBuildInputs = [ pkgs.bashInteractive ];
          # # packages = [ pkgs.bashInteractive ]; };
          #   buildInputs = with pkgs; [
          #   (wrapHelm kubernetes-helm {
          #     plugins = with pkgs.kubernetes-helmPlugins; [
          #       helm-diff
          #       helm-secrets
          #       helm-s3
          #     ];
          #   })
          # ];
      };
      }
    );
}
