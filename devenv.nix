{ pkgs, ... }:
let
  gdk = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components;
    [
      gke-gcloud-auth-plugin
    ]
  );
  my-kubernetes-helm =
    with pkgs;
    wrapHelm kubernetes-helm {
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
  # Enable devenv shell features
  packages = with pkgs; [
    bashInteractive
    zsh
    git
    ansible
    # terraform
    my-kubernetes-helm
    my-helmfile
    kubectl
    kubectx
    kubetail
    kind
    nixpkgs-fmt
    scaleway-cli
    sops
    opentofu
    awscli
    gdk
    # google-cloud-sdk
  ];
  # languages.terraform.enable = true;

  env = {
    # Environment variables
    SHELL = "{pkgs.zsh}/bin/zsh";
  };

  enterShell = '''';

  # Language configurations
  languages.nix.enable = true;

}
