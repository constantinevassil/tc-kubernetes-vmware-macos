

# tc-kubernetes-virtualbox-macos

Vagrant config to run a full local Kubernetes cluster using the source directory from your Mac.

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
     
* update VMWare box

  Install by running: 
    
```bash
   vagrant box add bento/ubuntu-16.04
```
    
* run Virtual machine (VM)

  Install by running: 
  
```bash
    vagrant up --provider vmware_fusion
```

## Using kubeadm to create a cluster - single machine configuration. To schedule pods on master node.

Kubernetes is hard to install without using third party tools. kubeadm is an official tool for simple deployment. 

* Before you begin
	1.	One or more virtual machines running Ubuntu 16.04+
	1.	1GB or more of RAM per machine (any less will leave little room for your apps)
	1.	Full network connectivity between all machines in the cluster

* Objectives
	* Install a secure Kubernetes cluster on your machines
	* Install a pod network on the cluster so that application components (pods) can talk to each other
	* Install a sample Golang application on the cluster

Everything is done manually for a better understanding of the process. Here is Vagrantfile I used to run 1 VM:

```javascript
Vagrant.configure("2") do |config|
    config.vm.box = "bento/ubuntu-16.04"
    config.vm.synced_folder ENV['HOME'], "/myhome", type: "nfs"

    config.vm.provider "vmware_fusion" do |v|
      v.memory = 2048
      v.cpus = 1
    end
 
    config.vm.define "master" do |node|
      node.vm.hostname = "master"
      node.vm.network :private_network, ip: "192.168.44.10"
      node.vm.provision :shell, inline: "sed 's/127\.0\.0\.1.*master.*/192\.168\.44\.10 master/' -i /etc/hosts"
    end

end
```

NOTE: 
Check your IP address for conflicts on your local network:
node.vm.network :private_network, ip: "192.168.44.10"

After VM is up and running the first step is to add official Kubernetes repo and to install all required packages.

### Install all required packages
#### 1. On master

```bash
vagrant ssh master
ubuntu@master:~$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
ubuntu@master:~$ echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
ubuntu@master:~$ sudo apt-get update && sudo apt-get install -y docker-engine kubelet kubeadm kubectl kubernetes-cni
ubuntu@master:~$ exit
```

#### 4. Start cluster initialization on the master node.

When using flannel as the pod network (described in step 6.), specify --pod-network-cidr=10.244.0.0/16. 

```bash
vagrant ssh master
ubuntu@master:~$ sudo kubeadm init --apiserver-advertise-address 192.168.44.10 --pod-network-cidr 10.244.0.0/16 --token 8c2350.f55343444a6ffc46
```


#### 5. To start using your cluster, you need to run (as a regular user):

```bash
ubuntu@master:~$ mkdir -p $HOME/.kube
ubuntu@master:~$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
ubuntu@master:~$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

for a single-machine Kubernetes cluster, run:

```bash
kubectl taint nodes --all node-role.kubernetes.io/master-
```

That way, pods will actually schedule on a master node.

#### 6. You should now deploy a pod network to the cluster.

Flannel RBAC:
```bash
ubuntu@master:~$ curl -O https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
ubuntu@master:~$ kubectl apply -f kube-flannel-rbac.yml
```

Flannel config:
```bash
ubuntu@master:~$ curl -O https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
ubuntu@master:~$ kubectl apply -f kube-flannel.yml
```

#### 7. Check the cluster initialization:
```bash
ubuntu@master:~$ kubectl get pods -o wide --all-namespaces
```

After successfull initialization you should get:
```bash
ubuntu@master:~$ kubectl get pods -o wide --all-namespaces
NAMESPACE     NAME                             READY     STATUS    RESTARTS   AGE       IP              NODE
kube-system   etcd-master                      1/1       Running   0          8m        192.168.33.10   master
kube-system   kube-apiserver-master            1/1       Running   0          8m        192.168.33.10   master
kube-system   kube-controller-manager-master   1/1       Running   0          8m        192.168.33.10   master
kube-system   kube-dns-2425271678-d5b85        3/3       Running   0          13m       10.244.0.2      master
kube-system   kube-flannel-ds-vkcqt            2/2       Running   0          1m        192.168.33.10   master
kube-system   kube-proxy-vthjs                 1/1       Running   0          13m       192.168.33.10   master
kube-system   kube-scheduler-master            1/1       Running   0          8m        192.168.33.10   master
ubuntu@master:~$ exit
```


#### 9. Check the nodes creation:

```bash
vagrant ssh master
ubuntu@master:~$ kubectl get nodes
```

After successfully adding nodes you should get:
```bash
ubuntu@master:~$ kubectl get nodes
NAME      STATUS    AGE       VERSION
master    Ready     19h       v1.7.1
```


## Testing kubernetes from inside the master

### 1. Create a deployment that manages a Pod. 

deploy topconnector/tc-helloworld-go-ws

```bash
vagrant ssh master
ubuntu@master:~$ kubectl run tc-helloworld-go-ws --image=topconnector/tc-helloworld-go-ws:v1 --port=8080 --record
```

Check rollout status:

```bash
ubuntu@master:~$ kubectl rollout status deployment/tc-helloworld-go-ws
deployment "helloworld-go-ws" successfully rolled out
```

View the Deployment:
```bash
ubuntu@master:~$ kubectl get deployments
NAME                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
tc-helloworld-go-ws          1         1         1            1           3m
```

View the Pods:

```bash
ubuntu@master:~$ kubectl get pods -o wide
NAME                                       READY     STATUS    RESTARTS   AGE       IP           NODE
tc-helloworld-go-ws-495672996-nt1m9           1/1       Running   0          5m        10.244.1.4   master
```

### 2. Scaling:
```bash
ubuntu@master:~$ kubectl scale --replicas=2 deployment/tc-helloworld-go-ws --record
deployment "helloworld-go-ws" scaled
```

### 3. Create a service:
```bash
ubuntu@master:~$ kubectl expose deployment tc-helloworld-go-ws --type=NodePort
service "helloworld-go-ws" exposed
```

### 4. Access the service:

1. get node "master"'s IP address:
```bash
ubuntu@master:~$ kubectl describe nodes

...
Addresses:
  InternalIP:	192.168.44.10
  Hostname:	master
...  
```

IP address:192.168.44.10


2. get service port number

View the services:
```bash
ubuntu@master:~$ kubectl get services
NAME                  CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes            10.96.0.1       <none>        443/TCP          8m
tc-helloworld-go-ws   10.104.31.142   <nodes>       8080:30350/TCP   1m
```
service port number:32658 

### 5. Test the service:

The http address of the service: 192.168.44.10:30350

```bash
ubuntu@master:~$ curl http://192.168.44.10:30350
Hello World from Go in minimal Docker container(4.28MB) v.1.0, it took 78ns to run
```

### 6. Update your app to version 2

```bash
ubuntu@master:~$ kubectl set image deployment/tc-helloworld-go-ws tc-helloworld-go-ws=topconnector/tc-helloworld-go-ws:v2 --record
deployment "tc-helloworld-go-ws" image updated
ubuntu@master:~$ curl http://192.168.33.10:30350
Hello World from Go in minimal Docker container(4.28MB) v.2.0, it took 68ns to run
```

### 7. Rollback your app to version 1

```bash
ubuntu@master:~$ kubectl rollout undo deployment tc-helloworld-go-ws
deployment "tc-helloworld-go-ws" rolled back
ubuntu@master:~$ curl http://192.168.33.10:30350
Hello World from Go in minimal Docker container(4.28MB) v.1.0, it took 68ns to run
```

### 8. Rollback your app to version 2

```bash
ubuntu@master:~$ kubectl rollout undo deployment tc-helloworld-go-ws
deployment "tc-helloworld-go-ws" rolled back
ubuntu@master:~$ curl http://192.168.33.10:30350
Hello World from Go in minimal Docker container(4.28MB) v.2.0, it took 68ns to run
```

## Access your cluster from your local machine

### 1. Get admin.conf from master

Get admin.conf from /etc/kubernetes on master and copy to your local machine's current folder:

```bash
ubuntu@master:~$ sudo cat /etc/kubernetes/admin.conf > /vagrant/admin.conf
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


### 3. Check master configuration 

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
tc-helloworld-go-ws   10.105.98.177   <nodes>       8080:32631/TCP   11h
```
	
## Dashboard

In order to get a nice GUI, we’ll set up a Dashboard.

Kube version 1.6 uses RBAC as a default form of auth.

### On master

### 1. Install the dashboard

```bash
ubuntu@master:~$ kubectl create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
```

### 2. Configure a role

We also need to configure a role.

copy from local folder:

```bash
ubuntu@master:~$ cat /vagrant/admin-role.yml > admin-role.yml
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
ubuntu@master:~$ kubectl apply -f admin-role.yml 
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
curl http://192.168.33.10:30350
```
