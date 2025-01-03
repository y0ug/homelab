#!/usr/bin/env bash
sops -d terraform/terraform.tfvars.enc >terraform/terraform.tfvars
sops -d .kube_config.yaml.enc >.kube_config.yaml
