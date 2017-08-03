#!/usr/bin/env bash

# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
# echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# sudo apt-get update && sudo apt-get install -y docker-engine kubelet kubeadm kubectl kubernetes-cni

# ifconfig
# ens33: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
#         inet 10.0.1.30  netmask 255.255.255.0  broadcast 10.0.1.255
#         inet6 fe80::20c:29ff:fe67:d7b1  prefixlen 64  scopeid 0x20<link>
#         ether 00:0c:29:67:d7:b1  txqueuelen 1000  (Ethernet)
#         RX packets 106  bytes 9801 (9.8 KB)
#         RX errors 0  dropped 0  overruns 0  frame 0
#         TX packets 18  bytes 2030 (2.0 KB)
#         TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

# sudo kubeadm init --apiserver-advertise-address 192.168.1.112 --pod-network-cidr 10.244.0.0/16 --token 8c2350.f55343444a6ffc46

# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config

# kubectl taint nodes --all node-role.kubernetes.io/master-

# curl -O https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
# kubectl apply -f kube-flannel-rbac.yml

# curl -O https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
# kubectl apply -f kube-flannel.yml

# kubectl get pods -o wide --all-namespaces

# sudo cat /etc/kubernetes/admin.conf > /vagrant/admin.conf

#copy admin.conf to $HOME/.kube/config and prepare to use locally.

# sudo mkdir -p $HOME/.kube
# sudo cp -i ./admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config
# sudo cat $HOME/.kube/config

# kubectl create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
# cat /vagrant/admin-role.yml > admin-role.yml

# kubectl apply -f admin-role.yml

# 
# kubectl apply -f /vagrant/tc-rocksdb-deployment01.yaml
# kubectl expose deployment tc-rocksdb-deployment --type=NodePort

# vagrant@tc-k-vm-master:~$ kubectl get svc -o wide
# NAME                    CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE       SELECTOR
# kubernetes              10.96.0.1       <none>        443/TCP          4m        <none>
# tc-rocksdb-deployment   10.101.72.203   <nodes>       8080:30493/TCP   10s       app=tc-rocksdb

# curl 192.168.2.114:30493
