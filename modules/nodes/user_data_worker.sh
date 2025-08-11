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

# # Get region
# region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')

# # Fetch the join command from SSM and execute it
# JOIN_CMD=$(aws ssm get-parameter --region "$region" --name "/k8s/join-command" --with-decryption --query "Parameter.Value" --output text)

# # Run the join command
# $JOIN_CMD

sleep 40

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d\" -f4)

JOIN_CMD=$(aws ssm get-parameter \
  --name "/k8s/join-command" \
  --region "$region" \
  --query "Parameter.Value" \
  --output text)

sudo $JOIN_CMD
