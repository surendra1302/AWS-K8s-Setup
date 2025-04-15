# IAM Instance Profile for EC2 Master
resource "aws_iam_instance_profile" "k8s_master_profile1" {
  name = "k8s-cluster-iam-master-profile1"
  role = aws_iam_role.k8s_master_role2.name
}

# EC2 Instance for Master Node
resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu_22_04.id
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.k8s_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.k8s_master_profile1.name
  key_name               = aws_key_pair.k8s_key_pair.key_name #var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  # Upload the script to the EC2 instance
  provisioner "file" {
    source      = "${path.module}/scripts/init-master.sh"
    destination = "/home/ubuntu/init-master.sh"

  }

  # Run the script on the EC2 instance
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/init-master.sh",
      "sudo /home/ubuntu/init-master.sh"
    ]

  }

   connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.k8s_ssh_key.private_key_pem
      host        = self.public_ip
    }
  tags = {
    Name = "Master"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_security_group" "k8s_sg" {
  name        = "k8s-master-sg"
  description = "Security Group for Kubernetes Master Node"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "etcd server client API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "kube-scheduler"
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "kube-controller-manager"
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Read-Only Kubelet API"
    from_port   = 10255
    to_port     = 10255
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Schedular"
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Controller"
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Internal communication within VPC
  ingress {
    description = "VPC Internal"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-master-sg"
  }
}

# IAM Role for Master Node
resource "aws_iam_role" "k8s_master_role2" {
  name = "k8s-cluster-iam-master-role2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "k8s-master-role"
  }
}

# IAM Policy for Master Node (read from your JSON file)
resource "aws_iam_policy" "k8s_master_policy1" {
  name        = "k8s-cluster-iam-master-policy1"
  description = "IAM Policy for Kubernetes Master Node"

  policy = file("${path.module}/policies/k8s-master-policy.json")
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach_master_policy" {
  role       = aws_iam_role.k8s_master_role2.name
  policy_arn = aws_iam_policy.k8s_master_policy1.arn
}

# Attach AmazonEC2FullAccess managed policy
resource "aws_iam_role_policy_attachment" "master_attach_ec2_full_access" {
  role       = aws_iam_role.k8s_master_role2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Attach AdministratorAccess managed policy
resource "aws_iam_role_policy_attachment" "master_attach_admin_access" {
  role       = aws_iam_role.k8s_master_role2.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
