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
systemctl enable --now kubelet

sleep 60

yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
sudo mkdir -p /root/.kube
aws ssm get-parameter --name "/k8s/kubeconfig" --with-decryption --region us-east-1 --query "Parameter.Value" --output text > /root/.kube/config
export KUBECONFIG=/root/.kube/config

sudo mkdir -p /home/ssm-user/.kube
sudo cp /root/.kube/config /home/ssm-user/.kube/config
sudo chown -R ssm-user:ssm-user /home/ssm-user/.kube

