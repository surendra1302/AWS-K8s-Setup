# VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                              = "K8s-cluster-vpc"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Subnet
resource "aws_subnet" "k8s_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "K8s-cluster-net"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "K8s-cluster-igw"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

# Route Table
resource "aws_route_table" "k8s_route_table" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "K8s-cluster-rtb"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.k8s_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.k8s_igw.id
}

resource "aws_route_table_association" "k8s_rta" {
  subnet_id      = aws_subnet.k8s_subnet.id
  route_table_id = aws_route_table.k8s_route_table.id
}


