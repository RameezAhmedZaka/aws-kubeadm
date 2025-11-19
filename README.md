


<img width="5547" height="4840" alt="k8s-aws-setup drawio" src="https://github.com/user-attachments/assets/524e883b-1b7b-4547-988c-4ec6765d4866" />


# Kubernetes Cluster Setup with ArgoCD and Automated Application Deployment

This repository demonstrates a complete **Kubernetes setup with ArgoCD** for deploying applications automatically. It includes Terraform-based infrastructure provisioning, cluster setup with a **node manager**, ArgoCD GitOps deployments, and CI/CD automation using GitHub Actions.

---

## Table of Contents

- [Overview](#overview)  
- [Repository Structure](#repository-structure)  
- [Architecture](#architecture)  
- [Prerequisites](#prerequisites)  
- [Setup Instructions](#setup-instructions)  
- [ArgoCD Deployment](#argocd-deployment)  
- [CI/CD Pipeline](#ci-cd-pipeline)  
- [Useful Commands](#useful-commands)  
- [License](#license)  

---

## Overview

This project automates:

1. Provisioning a network (VPC, subnets, and a bastion host) via Terraform.  
2. Setting up a Kubernetes cluster with:
   - 1 **Node Manager**  
   - 1 **Master Node**  
   - 2 **Worker Nodes**  
3. Using AWS Systems Manager Parameter Store to securely share:
   - `kubeconfig` from Master Node → Node Manager  
   - `kubeadm join` command from Master → Worker Nodes  
4. Installing ArgoCD on the cluster and configuring it dynamically using **kubeconfig from Parameter Store**.  
5. Deploying applications through ArgoCD by pulling code from GitHub and using credentials stored in Parameter Store.  
6. Automating Docker image build and deployment using GitHub Actions.

---

## Repository Structure

.
- `network/` → Terraform scripts for **VPC, Bastion Host, and Node setup**
- `k8s-setup/` → Kubernetes cluster setup (Master + Workers + Node Manager + argocd installation)
- `.gitignore` → Git ignore file to exclude unnecessary files (e.g., `.terraform/`, state files)
- `README.md` → Project documentation

markdown
Copy code

---

## Architecture

### Cluster Setup

- **Node Manager:**  
  - Acts as the central node for managing the cluster.  
  - Has access to `kubeconfig` from parameter store and we can ssm.  

- **Master Node:**  
  - Generates `kubeconfig` and `kubeadm join` command.  
  - Pushes `kubeconfig` and join command to **Parameter Store**.
  -  - Do not have SSM access.    

- **Worker Nodes:**  
  - Retrieve the join command from Parameter Store to join the cluster.  
  - Do not have SSM access.  

### ArgoCD Integration

- Installed on the cluster.  
- Configured dynamically using the `kubeconfig` retrieved at runtime from Parameter Store.  
- Pulls manifiest code with the application image from GitHub **https://github.com/RameezAhmedZaka/argocd-dataapp.git** and deploys automatically.
- THe steps to download the argocd cli
  ```
  VERSION=v2.13.4
  curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
  chmod +x argocd
  sudo mv argocd /usr/local/bin/argocd
  export PATH=$PATH:/usr/local/bin
  ```
- To access the ui use
  ```
  nohup kubectl port-forward svc/argocd-server -n argocd 9090:443 > /var/log/argocd-portforward.log 2>&1 &) than will be accessible on [port 9090](https://localhost:9090/)
  ```
-  Initial username = admin and to get the password use ( kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d; echo)   

### CI/CD Flow

1. **[Application repo](https://github.com/RameezAhmedZaka/github-action-cicd.git)** contains code + Dockerfile.  
2. GitHub Actions builds a new Docker image whenever code changes.  
3. The image tag is updated in the ArgoCD deployment YAML.  
4. ArgoCD detects changes and deploys the updated application to the cluster.

---

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/)  
- [Terraform](https://www.terraform.io/)  
- [kubectl](https://kubernetes.io/docs/tasks/tools/)  
- GitHub repository for application code  
- Docker (optional, for local builds)  

---

## Setup Instructions

### 1. Network Setup

```bash
cd network
terraform init
terraform apply
```

### 2. K8s-setup Setup
- Inside from the bashion server.
```bash
cd k8s-setup
terraform init
terraform apply
```

### 3. Command to put the credentials on parameter store
```
aws ssm put-parameter   --name &quot;/credentials/dockerhub&quot;   --type &quot;SecureString&quot;   --value &apos;{&quot;auths&quot;:{&quot;https://index.docker.io/v1/&quot;:{&quot;auth&quot;:&quot;encode_value_of_username_token&quot;}}}&apos;
aws ssm put-parameter   --name "/credentials/github"   --type "SecureString"   --value '{"username":"RameezAhmedZaka","token":"abc"}'
```

### 4. Command to connect to the manager node
```
aws ssm start-session --target <Instance_id> --region us-east-1

```

