#!/bin/bash
# Redirect all output to logs
exec > >(tee -a /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Disable SELinux
setenforce 0
sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux

# Enable br_netfilter
modprobe br_netfilter
cat <<EOF > /etc/sysctl.d/kube.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# Install Docker
yum update -y
amazon-linux-extras enable docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Add Kubernetes repo
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

# Install kubeadm, kubelet, kubectl
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

# Wait for kubelet to be ready
sleep 60

# Install SSM agent
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Fetch kubeconfig from SSM Parameter Store
mkdir -p /root/.kube
sudo chmod 700 /root/.kube
aws ssm get-parameter --name "/k8s/kubeconfig" --with-decryption --region us-east-1 --query "Parameter.Value" --output text > /root/.kube/config
sudo chmod 600 /root/.kube/config
export KUBECONFIG=/root/.kube/config
sudo chown ec2-user:ec2-user /root/.kube/config
sudo chmod 600 /root/.kube/config

# Remove the invalid file
sudo rm -f /home/ssm-user/.kube

# Create the correct directory
sudo mkdir -p /home/ssm-user/.kube
sudo chown -R ssm-user:ssm-user /home/ssm-user/.kube

# Fetch kubeconfig into the correct file
sudo aws ssm get-parameter \
  --name "/k8s/kubeconfig" \
  --with-decryption \
  --region us-east-1 \
  --query "Parameter.Value" \
  --output text > /home/ssm-user/.kube/config

# Set proper permissions
sudo chown ssm-user:ssm-user /home/ssm-user/.kube/config
sudo chmod 600 /home/ssm-user/.kube/config


# Copy kubeconfig for ssm-user
sudo mkdir -p /home/ssm-user/.kube
sudo cp /root/.kube/config /home/ssm-user/.kube/config
sudo chown -R ssm-user:ssm-user /home/ssm-user/.kube

# Install git
yum install -y git

# Install Kustomize
cd /tmp
curl -LO https://github.com/kubernetes-sigs/kustomize/releases/latest/download/kustomize_v5.7.1_linux_amd64.tar.gz
tar -xzf kustomize_v5.7.1_linux_amd64.tar.gz
mv kustomize /usr/local/bin/
chmod +x /usr/local/bin/kustomize
kustomize version

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash
echo $PATH
echo 'export PATH=$PATH:/usr/local/bin' | sudo tee /etc/profile.d/helm.sh
source /etc/profile.d/helm.sh

# Install Helm
curl -LO https://get.helm.sh/helm-v3.12.3-linux-amd64.tar.gz
tar -zxvf helm-v3.12.3-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
chmod +x /usr/local/bin/helm
export PATH=$PATH:/usr/local/bin
helm version

# Wait until nodes are ready
echo "Waiting for all nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  --namespace kube-system \
  --create-namespace \
  --set controller.service.type=NodePort

# Wait for ingress pods
# kubectl wait --for=condition=Ready pod -n kube-system -l app.kubernetes.io/name=ingress-nginx --timeout=300s

# Install ArgoCD
# kubectl create namespace argocd
# curl -sSL -o /tmp/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# kubectl apply -n argocd -f /tmp/install.yaml --validate=false

# # Wait for ArgoCD server pod
# echo "Waiting for ArgoCD server pod..."
# kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# # Patch ArgoCD service to NodePort
# kubectl patch svc argocd-server -n argocd -p '{ "spec": { "type": "NodePort" } }'

# kubectl port-forward svc/argocd-server -n argo-cd 8080:443

# aws ssm start-session   --target i-02a96f3d1b2615d74   --document-name AWS-StartPortForwardingSession   --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
# argocd --port-forward --port-forward-namespace=argocd login --username=admin --password=liuELjtbWl843mCK


# nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 > /var/log/argocd-portforward.log 2>&1 &

# GIT_SECRET=$(aws secretsmanager get-secret-value --secret-id your-git-secret-name --query SecretString --output text)
# GIT_USERNAME=$(echo $GIT_SECRET | jq -r '.username')
# GIT_TOKEN=$(echo $GIT_SECRET | jq -r '.token')

# # Create ArgoCD secret for private Git repo
# kubectl create secret generic argocd-private-repo \
#   --namespace argocd \
#   --from-literal=url=git@github.com:your-org/your-kustomize-repo.git \
#   --from-literal=username=$GIT_USERNAME \
#   --from-literal=password=$GIT_TOKEN \
#   --dry-run=client -o yaml | kubectl apply -f -

# # Create ArgoCD Kustomize application
# cat <<EOF | kubectl apply -f -
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: my-kustomize-app
#   namespace: argocd
# spec:
#   project: default
#   source:
#     repoURL: "git@github.com:your-org/your-kustomize-repo.git"
#     targetRevision: main
#     path: "kustomize-directory"
#     kustomize:
#       namePrefix: "prod-"
#   destination:
#     server: "https://kubernetes.default.svc"
#     namespace: default
#   syncPolicy:
#     automated:
#       prune: true
#       selfHeal: true
# EOF




# # Get NodePort and internal IP
# ARGOCD_NODEPORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
# ARGOCD_NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# echo "ArgoCD NodePort: $ARGOCD_NODEPORT"
# echo "ArgoCD Node IP: $ARGOCD_NODE_IP"

# # Install socat
# yum install -y socat

# # Start socat for port forwarding
# pkill socat || true
# nohup socat TCP-LISTEN:8443,fork TCP:${ARGOCD_NODE_IP}:${ARGOCD_NODEPORT} > /tmp/socat.log 2>&1 &

# echo "ArgoCD should now be accessible at https://<private-node-ip>:8443"







# kubectl -n kube-system edit configmap coredns
# rometheus :9153
#         forward . 8.8.8.8 8.8.4.4
#         cache 30
#         loop
#         reload
#         loadbalance
#     }
# kind: Conf

# kubectl -n kube-system rollout restart deployment coredns



# VERSION=v2.13.4
# curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
# chmod +x argocd
# sudo mv argocd /usr/local/bin/argocd
