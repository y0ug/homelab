#/bin/sh
[ -z "$HOST" ] && HOST=k8s-worker-01.int.mazenet.org
echo $HOST
scp $HOST:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's|127.0.0.1|k8s-worker-01.int.mazenet.org|g' ~/.kube/config
