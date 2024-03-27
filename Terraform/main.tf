provider "aws" {
  region     = "eu-central-1"
  access_key = "AKIAVRUVUKIP3YFQVNJK"
  secret_key = "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"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] // Canonical
}

resource "aws_instance" "master_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "c6a.xlarge"

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  tags = {
    Name = "master-instance"
  }

  user_data = <<-EOF
    #!/bin/bash
    echo "ubuntu:test..123" | sudo chpasswd
    # Install Docker Engine
    usermod -aG sudo jati
    sudo apt-get update -y
    sudo apt-get install -y docker.io
    sudo docker swarm init



    # Install AWS CLI and configure
    sudo apt-get update -y
    sudo apt-get install -y awscli

    # Wait for a few seconds to ensure that the necessary components are ready
    sleep 30

    # Note: Avoid configuring AWS CLI with access keys here. Instead, use IAM roles.

    # Wait for 60 seconds to ensure worker node is ready to join
    sleep 60
  EOF
}

resource "aws_eip_association" "master_elastic_ip_association" {
  instance_id   = aws_instance.master_instance.id
  allocation_id = "eipalloc-0300292d73d5ca488"
}

output "master_instance_ip" {
  value = aws_instance.master_instance.public_ip
}

resource "aws_instance" "worker_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  tags = {
    Name = "worker-instance"
  }
  
  user_data = <<-EOF
    #!/bin/bash
    echo "ubuntu:test..123" | sudo chpasswd

    # Install Docker Engine
    sudo apt-get update -y
    sudo apt-get install -y docker.io

    # Install AWS CLI and configure
    sudo apt-get update -y
    sudo apt-get install -y awscli

    # Wait for a few seconds to ensure that the necessary components are ready
    sleep 30

    # Note: Avoid configuring AWS CLI with access keys here. Instead, use IAM roles.

    # Enable password authentication in SSH configuration  
    sudo sed -i '1s/^/PasswordAuthentication yes\n/' /etc/ssh/sshd_config
    
    # Restart SSH service
    sudo service ssh restart

  EOF

  depends_on = [aws_instance.master_instance]
}

output "worker_instance_ip" {
  value = aws_instance.worker_instance.public_ip
}