### Module Main
provider "aws" {
  region = "us-east-1"
}

# Définition du VPC
resource "aws_vpc" "main" {
  cidr_block = "${var.VPC_CIDR}"

  tags = {
    Name = "${var.VPC_name}"  
  }
}

# Creation des VPCs privés et publics

resource "aws_subnet" "vpc_private" {
  count = "${length(var.AZS)}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.VPC_CIDR,4,count.index)}"
  availability_zone = "${element(var.AZS, count.index)}"

  tags = {
    Name = "${var.VPC_name}-private-${element(var.AZS, count.index)}"
  }
}

resource "aws_subnet" "vpc_public" {
  count = "${length(var.AZS)}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.VPC_CIDR,4,15 - count.index)}"
  availability_zone = "${element(var.AZS, count.index)}"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.VPC_name}-public-${element(var.AZS, count.index)}"
  }
}

# Creation de l'internet gateway, porte de sortie de nos réseaux publics
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "${var.VPC_name}-igw"
  }
}

# Creation d'une paire de clé RSA
resource "aws_key_pair" "mykey" {
  key_name   = "${var.SSH_KEY_NAME}"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQve2TG/MUrn2Yvw9Y1YuVabYaF/zR9Fuv6AhhsLsnZSDsxW+nAqeGgQESX3TF7w7PmmQsQdJj/dhDjndjIrAigeOr1CAjFHoYVMjE2k3epO4yivgkpKMNzfJGqJ934jE0X6NHl9767/PeschGFHUlIN2trMcnD6YdL3QWPz2w4yz8dhCp1KPuHbiPZguZSqTZ2i6Rm9cTTdso+APTq4f/tbyHLrA2icswyQ7kFII7VP4RHpOazt7XkBul5eFEA/3/ks8Al7AbpdcRuq7uPIYvD9HmyN2+stzdaBS9xHJs0DIzzXnEhXsZqT3giAabTJhPhLJnf5yc60mlLt7p77+x nicolas.frbezar@gmail.com"
}

# Creation d'un Security group pour accéder aux instances par SSH
resource "aws_security_group" "nat_sg" {
  name = "nat_sg"
  description = "Nat sg"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all trafic egress"
  }

  tags = {
    Name = "NAT SG"
  }
}

# Récupération du NAT
data "aws_ami" "nat_ami" {
  most_recent      = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-hvm-*-x86_64-ebs"]
  }
}

# Creation d'un nat pour chacun des subnets (des AZs)
resource "aws_instance" "nat" {
  count = "${length(var.AZS)}"
  ami           = "${data.aws_ami.nat_ami.id}"
  instance_type = "t2.micro"
  subnet_id = "${element(aws_subnet.vpc_public.*.id, count.index)}"
  vpc_security_group_ids = ["${aws_security_group.nat_sg.id}"]
  key_name   = "${var.SSH_KEY_NAME}"

  tags = {
    Name = "${var.VPC_name}-nat-${element(var.AZS, count.index)}"
  }
}

# Creation d'EIP pour chacun des NATs
resource "aws_eip" "nat" {
  count = "${length(var.AZS)}"
  vpc      = true
}

# Association de chaque EIP vers leurs NAT
resource "aws_eip_association" "eip_assoc_nat" {
  count = "${length(var.AZS)}"
  instance_id   = "${element(aws_instance.nat.*.id, count.index)}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
}

# Creation des routings tables pour chacunes des zones de disponibilités privées
resource "aws_route_table" "private_routing_table" {
  count = "${length(var.AZS)}"
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${element(aws_instance.nat.*.id, count.index)}"
  }

  tags = {
    Name = "${var.VPC_name}-private-${element(var.AZS, count.index)}"
  }
}

# Association de chaque subnets à leurs propres NAT
resource "aws_route_table_association" "private_routing_table_association" {
  count = "${length(var.AZS)}"
  subnet_id      = "${element(aws_subnet.vpc_private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_routing_table.*.id, count.index)}"
}

# Creation de la routing table des subnets publics
resource "aws_route_table" "public_routing_table" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    Name = "${var.VPC_name}-public"
  }
}

# Association des subnets publics vers l'internet gateway
resource "aws_route_table_association" "public_routing_table_association" {
  count = "${length(var.AZS)}"
  subnet_id      = "${element(aws_subnet.vpc_public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public_routing_table.id}"
}