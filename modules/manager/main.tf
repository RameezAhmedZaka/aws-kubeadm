resource "aws_security_group" "bastion_sg" {
  name   = var.manager_sg_name
  vpc_id = var.vpc_id

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

resource "aws_instance" "manager" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile

  user_data                   = file("${path.module}/user_data_ssm.sh")

  tags = {
    Name    = var.manager_name
    Role    = var.manager_role
    Cluster = var.manager_cluster
  }
}
