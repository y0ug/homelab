#/bin/sh
[ -z "$HOSTNAME" ] && HOSTNAME=k8s-worker-01.int.mazenet.org
echo $HOSTNAME
scp $HOSTNAME:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's|127.0.0.1|k8s-worker-01.int.mazenet.org|g' ~/.kube/config
