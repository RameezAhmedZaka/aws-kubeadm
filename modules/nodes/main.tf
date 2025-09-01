resource "aws_security_group" "nodes_sg" {
  name   = "nodes-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.inbound_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.ingress_cidr_block] 
    }
  }

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
    cidr_blocks = [var.egress_cidr_block]
  }

  tags = {
    Name = var.sg_name
  }
}

resource "aws_security_group_rule" "allow_worker_to_master" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes_sg.id
  source_security_group_id = aws_security_group.nodes_sg.id
}


resource "aws_instance" "master" {
  ami                         = var.ami_id
  instance_type               = var.instance_type_master
  subnet_id                   = var.private_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.nodes_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile

  user_data = file("${path.module}/user_data_master.sh")

  tags = {
    Name    = var.master_node_name
    Role    = var.master_node_role
    Cluster = var.master_node_cluster
  }
}

resource "null_resource" "wait_for_join" {
  depends_on = [aws_instance.master]

  provisioner "local-exec" {
    command = <<EOT
echo "Sleeping for 200 seconds to allow master user-data to complete..."
sleep 200
echo "Waiting for /k8s/join-command SSM parameter..."
while ! aws ssm get-parameter --name "/k8s/join-command" --region us-east-1 &>/dev/null; do
  sleep 5
done
EOT
  }
}

resource "aws_instance" "workers" {
  count                       = 2
  ami                         = var.ami_id
  instance_type               = var.instance_type_worker
  subnet_id                   = element(var.private_subnet_ids, count.index + 1)
  vpc_security_group_ids      = [aws_security_group.nodes_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile
  user_data                   = file("${path.module}/user_data_worker.sh")
  
  depends_on                  = [aws_instance.master, null_resource.wait_for_join]

  tags = {
    Name    = "${var.worker_node_name}-${count.index + 1}"
    Role    =  var.worker_node_role
    Cluster =  var.worker_node_cluster


  }
}

resource "aws_ssm_document" "run_join_command" {
  name          = "RunJoinCommand"
  depends_on    = [ aws_instance.workers, aws_instance.master ]
  document_type = var.document_type

  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Run the kubeadm join command with retry loop",
    mainSteps = [
      {
        action = "aws:runShellScript",
        name   = "runJoin",
        inputs = {
          runCommand = [
            "region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d\\\" -f4)",
            "for i in {1..30}; do",
            "  JOIN_CMD=$(aws ssm get-parameter --name /k8s/join-command --region $region --query 'Parameter.Value' --output text 2>/dev/null)",
            "  if [ -n \"$JOIN_CMD\" ]; then",
            "    sudo $JOIN_CMD",
            "    break",
            "  fi",
            "  echo \"Waiting for master... attempt $i\"",
            "  sleep 10",
            "done"
          ]
        }
      }
    ]
  })
}


resource "aws_ssm_document" "configure_kubeconfig" {
  name          = "ConfigureKubeConfig"
  document_type = var.document_type

  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Fetch and configure kubeconfig",
    mainSteps = [
      {
        action = "aws:runShellScript",
        name   = "setupKubeconfig",
        inputs = {
          runCommand = [
            "#!/bin/bash",
            "mkdir -p ~/.kube",
            "aws ssm get-parameter --name /k8s/kubeconfig --region ${var.region} --query 'Parameter.Value' --output text > ~/.kube/config",
            "chmod 600 ~/.kube/config"
          ]
        }
      }
    ]
  })
}


