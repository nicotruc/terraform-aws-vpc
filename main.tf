### Module Main
provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "main" {
  cidr_block = "${var.VPC_CIDR}"

  tags = {
    Name = "${var.VPC_name}"  
  }
}

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
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "${var.VPC_name}-igw"
  }
}

# Creation d'une paire de clé RSA
resource "aws_key_pair" "mykey" {
  key_name   = "ESIEE_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQve2TG/MUrn2Yvw9Y1YuVabYaF/zR9Fuv6AhhsLsnZSDsxW+nAqeGgQESX3TF7w7PmmQsQdJj/dhDjndjIrAigeOr1CAjFHoYVMjE2k3epO4yivgkpKMNzfJGqJ934jE0X6NHl9767/PeschGFHUlIN2trMcnD6YdL3QWPz2w4yz8dhCp1KPuHbiPZguZSqTZ2i6Rm9cTTdso+APTq4f/tbyHLrA2icswyQ7kFII7VP4RHpOazt7XkBul5eFEA/3/ks8Al7AbpdcRuq7uPIYvD9HmyN2+stzdaBS9xHJs0DIzzXnEhXsZqT3giAabTJhPhLJnf5yc60mlLt7p77+x nicolas.frbezar@gmail.com"
}

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

resource "aws_instance" "nat" {
  count = "${length(var.AZS)}"
  ami           = "${data.aws_ami.nat_ami.id}"
  instance_type = "t2.micro"
  subnet_id = "${element(aws_subnet.vpc_private.*.id, count.index)}"

  tags = {
    Name = "${var.VPC_name}-nat-${element(var.AZS, count.index)}"
  }
}

