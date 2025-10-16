# ----------------------------
# Security Group for Manager
# ----------------------------
resource "aws_security_group" "bastion_sg" {
  name   = var.manager_sg_name
  vpc_id = var.vpc_id
  
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.manager_sg_egress_cidr
  }

  tags = {
    Name = var.manager_sg_name
  }
}

resource "aws_security_group_rule" "allow_manager_to_master_api" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

# ----------------------------
# Wait until master + workers are up
# ----------------------------
resource "null_resource" "wait_for_nodes" {
  triggers = {
    master  = var.master_instance_id
    workers = join(",", var.worker_instance_id)
  }
}

# ----------------------------
# Manager EC2 Instance
# ----------------------------
resource "aws_instance" "manager" {
  depends_on = [null_resource.wait_for_nodes]

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile

  user_data = file("${path.module}/user_data_ssm.sh")

  tags = {
    Name    = var.manager_name
    Role    = var.manager_role
    Cluster = var.manager_cluster
  }
}

resource "null_resource" "wait_for_ssm" {
  provisioner "local-exec" {
    command = <<EOT
    for i in {1..10}; do
      aws ssm describe-instance-information --filters "Key=InstanceIds,Values=${aws_instance.manager.id}" --region us-east-1 | grep ${aws_instance.manager.id} && exit 0
      echo "Waiting for SSM agent..."
      sleep 15
    done
    exit 1
    EOT
  }
}

# ----------------------------
# Wait + Fetch kubeconfig Locally
# ----------------------------
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [aws_instance.manager, null_resource.wait_for_nodes, null_resource.wait_for_ssm]

  provisioner "local-exec" {
    command = <<EOT
      echo "⌛ Waiting up to 10 minutes for kubeconfig on manager..."

      INSTANCE_ID=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${var.manager_name}" \
        --query "Reservations[0].Instances[0].InstanceId" \
        --output text)

      for i in {1..20}; do
        CMD_ID=$(aws ssm send-command \
          --targets "Key=instanceIds,Values=$INSTANCE_ID" \
          --document-name "AWS-RunShellScript" \
          --comment "Check kubeconfig" \
          --parameters 'commands=["test -f /etc/kubernetes/admin.conf && echo exists || echo missing"]' \
          --query "Command.CommandId" \
          --output text)

        sleep 10

        STATUS=$(aws ssm get-command-invocation \
          --command-id $CMD_ID \
          --instance-id $INSTANCE_ID \
          --query "StandardOutputContent" \
          --output text)

        if [ "$STATUS" = "exists" ]; then
          echo "Kubeconfig ready, downloading..."

          CMD_ID=$(aws ssm send-command \
            --targets "Key=instanceIds,Values=$INSTANCE_ID" \
            --document-name "AWS-RunShellScript" \
            --comment "Fetch kubeconfig" \
            --parameters 'commands=["cat /etc/kubernetes/admin.conf"]' \
            --query "Command.CommandId" \
            --output text)

          sleep 10

          aws ssm get-command-invocation \
            --command-id $CMD_ID \
            --instance-id $INSTANCE_ID \
            --query "StandardOutputContent" \
            --output text > kubeconfig.yaml

          echo "Kubeconfig saved to kubeconfig.yaml"
          break
        else
          echo "Not ready yet, retrying..."
          sleep 20
        fi
      done
    EOT
  }
}
# ----------------------------
# Install Sealed Secrets via Helm
# -----------------------------

resource "helm_release" "sealed_secrets" {
  depends_on = [null_resource.wait_for_ssm]

  name             = "sealed-secrets"
  repository       = "https://bitnami-labs.github.io/sealed-secrets"
  chart            = "sealed-secrets"
  namespace        = "kube-system"
  create_namespace = false
  version          = "2.16.2"
}

# ----------------------------
# Install kubeseal CLI + Seal and Apply Secret (Remote)
# -----------------------------
resource "aws_ssm_document" "install_kubeseal" {
  name          = "install_kubeseal"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Run commands to install kubeseal",
    mainSteps = [
      {
        action = "aws:runShellScript",
        name   = "run_install_kubeseal",
        inputs = {
          runCommand = [
            "#!/bin/bash",
            "curl -OL https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.32.2/kubeseal-0.32.2-linux-amd64.tar.gz",
            "tar -xvzf kubeseal-0.32.2-linux-amd64.tar.gz kubeseal",
            "sudo install -m 755 kubeseal /usr/local/bin/kubeseal",
            "export KUBECONFIG=/root/.kube/config",
            "kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=kube-system > my-cluster-cert.pem",
            "kubectl create secret generic my-secret --from-literal=username=admin --from-literal=password=Test123 --dry-run=client -o yaml > /tmp/my-secret.yaml",
            "kubeseal --cert my-cluster-cert.pem --format yaml < /tmp/my-secret.yaml > /tmp/my-secret-sealed.yaml",
            "kubectl apply -f /tmp/my-secret-sealed.yaml"
          ]
        }
      }
    ]
  })
}

resource "null_resource" "run_kubeseal_ssm" {
  depends_on = [aws_ssm_document.install_kubeseal, helm_release.sealed_secrets]
  triggers = {
    always_run = timestamp()  # This changes every apply
  }
  provisioner "local-exec" {
    command = <<EOT
aws ssm send-command \
  --targets "Key=instanceIds,Values=${aws_instance.manager.id}" \
  --document-name ${aws_ssm_document.install_kubeseal.name} \
  --region us-east-1
EOT
  }
}
