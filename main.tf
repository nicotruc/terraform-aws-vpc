### Module Main
provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "main" {
  cidr_block = "${var.VPC_subnet_CIDR}"

  tags = {
    Name = "${var.VPC_name}"  
  }
}

resource "aws_subnet" "vpc_private" {
  count = "${length(var.AZS)}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.VPC_subnet_CIDR,4,count.index)}"
  availability_zone = "${element(var.AZS, count.index)}"

  tags = {
    Name = "${var.VPC_name}-private-${element(var.AZS, count.index)}"
  }
}

resource "aws_subnet" "vpc_public" {
  count = "${length(var.AZS)}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.VPC_subnet_CIDR,4,15 - count.index)}"
  availability_zone = "${element(var.AZS, count.index)}"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.VPC_name}-public-${element(var.AZS, count.index)}"
  }
}