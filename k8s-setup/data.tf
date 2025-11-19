# ----------------------------
# VPC Data Source
# ----------------------------
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["my-k8s-vpc"]
  }
}

# ----------------------------
# Subnets Data Source
# ----------------------------
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Type"
    values = ["public"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}


