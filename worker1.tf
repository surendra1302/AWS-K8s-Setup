# IAM Role for Worker Node
resource "aws_iam_role" "k8s_worker_role1" {
  name = "k8s-cluster-iam-worker-role1"

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
    Name = "k8s-worker-role"
  }
}

# IAM Policy for Worker Node (read from your JSON file)
resource "aws_iam_policy" "k8s_worker_policy1" {
  name        = "k8s-cluster-iam-worker-policy1"
  description = "IAM Policy for Kubernetes Worker Node"

  policy = file("${path.module}/policies/k8s-worker-policy.json")
}

# Attach the policy to the worker role
resource "aws_iam_role_policy_attachment" "attach_worker_policy1" {
  role       = aws_iam_role.k8s_worker_role1.name
  policy_arn = aws_iam_policy.k8s_worker_policy1.arn
}

# Attach AmazonEC2FullAccess managed policy
resource "aws_iam_role_policy_attachment" "attach_ec2_full_access1" {
  role       = aws_iam_role.k8s_worker_role1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Attach AdministratorAccess managed policy
resource "aws_iam_role_policy_attachment" "attach_admin_access" {
  role       = aws_iam_role.k8s_worker_role1.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# IAM Instance Profile for EC2 Worker
resource "aws_iam_instance_profile" "k8s_worker_profile1" {
  name = "k8s-cluster-iam-worker-profile1"
  role = aws_iam_role.k8s_worker_role1.name
}

resource "aws_security_group" "k8s_worker_sg" {
  name        = "k8s-worker-sg"
  description = "Security Group for Kubernetes Worker Node"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Protocol HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Protocol HTTPS"
    from_port   = 443
    to_port     = 443
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
    description = "Read-Only Kubelet API"
    from_port   = 10255
    to_port     = 10255
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "VPC Subnet"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-worker-sg"
  }
}

# EC2 Instance for Worker Node
resource "aws_instance" "k8s_worker" {
  depends_on = [
    aws_instance.k8s_master]
  ami                         = data.aws_ami.ubuntu_22_04.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.k8s_subnet.id
  iam_instance_profile        = aws_iam_instance_profile.k8s_worker_profile1.name
  key_name                    = aws_key_pair.k8s_key_pair.key_name #var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.k8s_worker_sg.id]

  tags = {
    Name = "Worker-1"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}


#Null resource to get the join command
resource "null_resource" "copy_join_script_to_worker" {
  depends_on = [
    aws_instance.k8s_master,
    aws_instance.k8s_worker
  ]

  provisioner "remote-exec" {
    inline = [
      # Write the private key on the worker so it can SSH into the master
      "echo '${tls_private_key.k8s_ssh_key.private_key_pem}' > /home/ubuntu/k8s-key.pem",
      "chmod 400 /home/ubuntu/k8s-key.pem",

      # Copy the file from master to worker
      "scp -o StrictHostKeyChecking=no -i /home/ubuntu/k8s-key.pem ubuntu@${aws_instance.k8s_master.private_ip}:/home/ubuntu/join-command.sh /home/ubuntu/"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.k8s_worker.public_ip
      private_key = tls_private_key.k8s_ssh_key.private_key_pem
    }
  }
}


resource "null_resource" "init_worker" {
  depends_on = [null_resource.copy_join_script_to_worker]

  provisioner "file" {
    source      = "${path.module}/scripts/init-worker.sh"
    destination = "/home/ubuntu/init-worker.sh"

  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/init-worker.sh",
      "sudo /home/ubuntu/init-worker.sh"
    ]
  }
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.k8s_ssh_key.private_key_pem
      host        = aws_instance.k8s_worker.public_ip
    }
  
}

