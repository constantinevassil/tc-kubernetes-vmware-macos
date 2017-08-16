

# tc-kubernetes-virtualbox-macos

Vagrant config to run a full local Kubernetes cluster using the source directory from your Mac under VMWare Fusion.

## Getting started

On Mac

```bash
git clone https://github.com/topconnector/tc-kubernetes-vmware-macos.git
cd tc-kubernetes-vmware-macos
cd single-machine
```

You must have the following installed:

* VMware Fusion (Pro) >= 8.5
  
  https://www.vmware.com/products/fusion/fusion-evaluation.html
    
* Vagrant >= 1.9.7

  Download and install from https://www.vagrantup.com/.

  Vagrant + VMware
  
  Download and install from https://www.vagrantup.com/vmware/index.html
     
```bash
    vagrant plugin install vagrant-vmware-fusion
    vagrant plugin license vagrant-vmware-fusion ~/license.lic
```

* run Virtual machine (VM)

  Install by running: 
  
```bash
    vagrant up --provider vmware_fusion
```

## Using kubeadm to create a cluster - single machine configuration. To schedule pods on master node.

Kubernetes is hard to install without using third party tools. kubeadm is an official tool for simple deployment. 

* Before you begin
	1.	One or more virtual machines running Ubuntu 17.04+
	1.	1GB or more of RAM per machine (any less will leave little room for your apps)
	1.	Full network connectivity between all machines in the cluster

* Objectives
	* Install a secure Kubernetes cluster on your machines
	* Install a pod network on the cluster so that application components (pods) can talk to each other
	* Install a sample Golang application on the cluster

Everything is done manually for a better understanding of the process. Here is Vagrantfile I used to run 1 VM:

```ruby
# vi: set ft=ruby :
 
Vagrant.configure("2") do |config|
    config.vm.box = "bento/ubuntu-17.04"
    config.vm.provider "vmware_fusion" do |v|
      v.memory = 2048
      v.cpus = 1
      v.gui = true
 
    end
 
    config.vm.define "tc-k-vm-master" do |node|
      node.vm.hostname = "tc-k-vm-master"
      node.vm.network :public_network
      node.vm.provision :shell, path: "bootstrap.sh"
    end 
end
```

NOTE: 
node.vm.network :public_network
This will automatically assign an IP address from the reserved address space. The IP address can be determined by using vagrant ssh to SSH into the machine and using the appropriate command line tool to find the IP, such as ifconfig.
 
 # eth0 in Vagrant for now is always NAT. 

```bash
ens33: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.100.129  netmask 255.255.255.0  broadcast 172.16.100.255
        inet6 fe80::20c:29ff:feeb:cf3a  prefixlen 64  scopeid 0x20<link>
        ether 00:0c:29:eb:cf:3a  txqueuelen 1000  (Ethernet)
        RX packets 665  bytes 88932 (88.9 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 510  bytes 367840 (367.8 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

In this case IP address is: 172.16.100.129, netmask 255.255.255.0 
To assign statis IP Address to Vagrantfile, replace 
      node.vm.network :public_network
with:
      node.vm.network "public_network", bridge: 'en0: Ethernet', ip: "172.16.100.129", netmask: "255.255.255.0"
Then
```bash
	vagrant reload
```
Then you can ping 172.16.100.129 from another computer on same network.

After VM is up and running the first step is to add official Kubernetes repo and to install all required packages.

### Install all required packages
#### 1. On master

```bash
vagrant ssh tc-k-vm-master
vagrant@tc-k-vm-master:~$ sudo apt-get update && sudo apt-get dist-upgrade
vagrant@tc-k-vm-master:~$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
vagrant@tc-k-vm-master:~$ echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
vagrant@tc-k-vm-master:~$ sudo apt-get update && apt-get upgrade && sudo apt-get install -y docker-engine kubelet kubeadm kubectl kubernetes-cni
vagrant@tc-k-vm-master:~$ exit
```

#### 4. Start cluster initialization on the master node.

When using flannel as the pod network (described in step 6.), specify --pod-network-cidr=10.244.0.0/16. 

Use IP address: 172.16.100.129

```bash
vagrant ssh tc-k-vm-master
vagrant@tc-k-vm-master:~$ sudo kubeadm init --apiserver-advertise-address 172.16.100.129 --pod-network-cidr 10.244.0.0/16 --token 8c2350.f55343444a6ffc46
```


#### 5. To start using your cluster, you need to run (as a regular user):

```bash
vagrant@tc-k-vm-master:~$ mkdir -p $HOME/.kube
vagrant@tc-k-vm-master:~$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
vagrant@tc-k-vm-master:~$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

for a single-machine Kubernetes cluster, run:

```bash
vagrant@tc-k-vm-master:~$ kubectl taint nodes --all node-role.kubernetes.io/master-
```

That way, pods will actually schedule on a master node.

#### 6. You should now deploy a pod network to the cluster.

Flannel RBAC:
```bash
vagrant@tc-k-vm-master:~$ curl -O https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
vagrant@tc-k-vm-master:~$ kubectl apply -f kube-flannel-rbac.yml
```

Flannel config:
```bash
vagrant@tc-k-vm-master:~$ curl -O https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
vagrant@tc-k-vm-master:~$ kubectl apply -f kube-flannel.yml
```

#### 7. Check the cluster initialization:
```bash
vagrant@tc-k-vm-master:~$ kubectl get pods -o wide --all-namespaces
```

After successfull initialization you should get:
```bash
vagrant@tc-k-vm-master:~$ kubectl get pods -o wide --all-namespaces
NAMESPACE     NAME                             READY     STATUS    RESTARTS   AGE       IP              NODE
kube-system   etcd-master                      1/1       Running   0          8m        192.168.33.10   master
kube-system   kube-apiserver-master            1/1       Running   0          8m        192.168.33.10   master
kube-system   kube-controller-manager-master   1/1       Running   0          8m        192.168.33.10   master
kube-system   kube-dns-2425271678-d5b85        3/3       Running   0          13m       10.244.0.2      master
kube-system   kube-flannel-ds-vkcqt            2/2       Running   0          1m        192.168.33.10   master
kube-system   kube-proxy-vthjs                 1/1       Running   0          13m       192.168.33.10   master
kube-system   kube-scheduler-master            1/1       Running   0          8m        192.168.33.10   master
vagrant@master:~$ exit
```


#### 9. Check the nodes creation:

```bash
vagrant ssh master
vagrant@tc-k-vm-master:~$ kubectl get nodes
```

After successfully adding nodes you should get:
```bash
vagrant@tc-k-vm-master:~$ kubectl get nodes
NAME      STATUS    AGE       VERSION
master    Ready     19h       v1.7.1
```


## Testing kubernetes from inside the master

### 1. Create a deployment that manages a Pod. 

deploy topconnector/tc-helloworld-go-ws

```bash
vagrant ssh master
vagrant@tc-k-vm-master:~$ kubectl run tc-helloworld-go-ws --image=topconnector/tc-helloworld-go-ws:v1 --port=8080 --record
```

Check rollout status:

```bash
vagrant@tc-k-vm-master:~$ kubectl rollout status deployment/tc-helloworld-go-ws
deployment "tc-helloworld-go-ws" successfully rolled out
```

View the Deployment:
```bash
vagrant@tc-k-vm-master:~$ kubectl get deployments
NAME                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
tc-helloworld-go-ws          1         1         1            1           3m
```

View the Pods:

```bash
vagrant@tc-k-vm-master:~$ kubectl get pods -o wide
NAME                                       READY     STATUS    RESTARTS   AGE       IP           NODE
tc-helloworld-go-ws-495672996-nt1m9           1/1       Running   0          5m        10.244.1.4   master
```

### 2. Scaling:
```bash
vagrant@tc-k-vm-master:~$ kubectl scale --replicas=2 deployment/tc-helloworld-go-ws --record
deployment "tc-helloworld-go-ws" scaled
```

### 3. Create a service:
```bash
vagrant@tc-k-vm-master:~$ kubectl expose deployment tc-helloworld-go-ws --type=NodePort
service "tc-helloworld-go-ws" exposed
```

### 4. Access the service:

1. get node "master"'s IP address:
```bash
vagrant@tc-k-vm-master:~$ kubectl describe nodes

...
Addresses:
  InternalIP:	192.168.232.137
  Hostname:	master...  
```

IP address:192.168.44.10


2. get service port number

View the services:
```bash
vagrant@tc-k-vm-master:~$ kubectl get services
NAME                  CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes            10.96.0.1       <none>        443/TCP          8m
tc-helloworld-go-ws   10.104.31.142   <nodes>       8080:30947/TCP   1m
```
service port number:32658 

### 5. Test the service:

The http address of the service: 192.168.232.137:30947

```bash
vagrant@tc-k-vm-master:~$ curl http://192.168.232.137:30947
Hello World from Go in minimal Docker container(4.28MB) v.1.0, it took 78ns to run
```

### 6. Update your app to version 2

```bash
vagrant@tc-k-vm-master:~$ kubectl set image deployment/tc-helloworld-go-ws tc-helloworld-go-ws=topconnector/tc-helloworld-go-ws:v2 --record
deployment "tc-helloworld-go-ws" image updated
vagrant@tc-k-vm-master:~$ curl http://192.168.232.137:30947
Hello World from Go in minimal Docker container(4.28MB) v.2.0, it took 68ns to run
```

### 7. Rollback your app to version 1

```bash
vagrant@tc-k-vm-master:~$ kubectl rollout undo deployment tc-helloworld-go-ws
deployment "tc-helloworld-go-ws" rolled back
vagrant@tc-k-vm-master:~$ curl http://192.168.232.137:30947
Hello World from Go in minimal Docker container(4.28MB) v.1.0, it took 68ns to run
```

### 8. Rollback your app to version 2

```bash
vagrant@tc-k-vm-master:~$ kubectl rollout undo deployment tc-helloworld-go-ws
deployment "tc-helloworld-go-ws" rolled back
vagrant@tc-k-vm-master:~$ curl http://192.168.232.137:30947
Hello World from Go in minimal Docker container(4.28MB) v.2.0, it took 68ns to run
```

## Installing with configuration files:

```bash
kubectl apply --filename  https://raw.githubusercontent.com/topconnector/tc-kubernetes-vmware-macos/master/single-machine/tc-helloworld-go-ws-deployment.yaml
kubectl apply --filename  https://raw.githubusercontent.com/topconnector/tc-kubernetes-vmware-macos/master/single-machine/tc-helloworld-go-ws-svc.yaml

```


## Access your cluster from your local machine

### 1. Get admin.conf from master

Get admin.conf from /etc/kubernetes on master and copy to your local machine's current folder:

```bash
vagrant@tc-k-vm-master:~$ sudo cat /etc/kubernetes/admin.conf > /vagrant/admin.conf
exit
```

on your your local machine:

copy admin.conf to $HOME/.kube/config and prepare to use locally.

```bash
sudo mkdir -p $HOME/.kube
sudo cp -i ./admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sudo cat $HOME/.kube/config
```


### 2. Install and Set Up kubectl on your local machine

Now in order for you to actually access your cluster from your Mac you need kubectl locally.

Download the latest release with the command:

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl

Make the kubectl binary executable.

chmod +x ./kubectl

Move the binary in to your PATH.

sudo mv ./kubectl /usr/local/bin/kubectl


### 3. Check the master configuration 

Get nodes:

```bash
kubectl get nodes
AME      STATUS    AGE       VERSION
master    Ready     11h       v1.7.1
```
Get pods:

```bash
kubectl get pods
NAME                                   READY     STATUS    RESTARTS   AGE
tc-helloworld-go-ws-1724924830-gpf9c   1/1       Running   0          11h
tc-helloworld-go-ws-1724924830-wv4f1   1/1       Running   0          11h
```

Get services:

```bash
kubectl get services
NAME                  CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes            10.96.0.1       <none>        443/TCP          11h
tc-helloworld-go-ws   10.105.98.177   <nodes>       8080:30947/TCP   11h
```
	
## Dashboard

In order to get a nice GUI, we’ll set up a Dashboard.

Kube version 1.6 uses RBAC as a default form of auth.

### On master

### 1. Install the dashboard

```bash
vagrant@tc-k-vm-master:~$ kubectl create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
```

### 2. Configure a role

We also need to configure a role.

copy from local folder:

```bash
vagrant@tc-k-vm-master:~$ cat /vagrant/admin-role.yml > admin-role.yml
```

Or in a text editor of your choice (vim) create admin-role.yml on master:
 
```yaml
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: admin-role
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin-role
subjects:
- kind: Group
  name: admin
- kind: ServiceAccount
  name: default
  namespace: kube-system
  ```

```bash
vagrant@master:~$ kubectl apply -f admin-role.yml 
```

### On local machine

Run proxy to use dashboard locally:

```bash
kubectl proxy
```

Proxy should be listening on 127.0.0.1:8001. 

Point your browser to http://127.0.0.1:8001/ui

Access the service from local machine:

```bash
curl http://192.168.232.137:30947
```
