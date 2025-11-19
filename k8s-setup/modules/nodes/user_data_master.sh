#!/bin/bash
# Disable swap
exec > >(tee -a /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Set SELinux to permissive
setenforce 0
sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux

# Enable br_netfilter and sysctl settings
modprobe br_netfilter
cat <<EOF > /etc/sysctl.d/kube.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# Install Docker
sudo yum update -y
sudo amazon-linux-extras enable docker
sudo yum install -y docker
systemctl enable docker
systemctl start docker

# Add Kubernetes repo
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

# Install kubelet, kubeadm, kubectl
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable kubelet

# Initialize the cluster
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

kubeadm init --pod-network-cidr=10.244.0.0/16 -v=9 --ignore-preflight-errors=NumCPU,Mem

mkdir -p /home/ec2-user/.kube
cp /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config

# Also set kubeconfig for root (optional)
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# Wait a bit to ensure API server is responsive
sleep 30

# Apply Flannel CNI (use ec2-user's context)
export KUBECONFIG=/home/ec2-user/.kube/config
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

sleep 30

sudo su

JOIN_CMD=$(kubeadm token create --print-join-command)

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d\" -f4)
aws ssm put-parameter \
  --name "/k8s/join-command" \
  --type "String" \
  --value "$JOIN_CMD" \
  --overwrite \
  --region "$region"




aws ssm put-parameter \
  --name "/k8s/kubeconfig" \
  --type "SecureString" \
  --tier Advanced \
  --value "$(cat /etc/kubernetes/admin.conf)" \
  --overwrite \
  --region us-east-1


