
## Bootstrap environment

```bash
cd repo/homelab/
load_env llm
nix develop
scripts/secrets.activate
tmux new-session -As homelab
```

## Execute command

On the k3s cluster, run the following command:

```bash
ansible k3s_cluster -b -m shell -a "uptime"
```
