output "private_subnet" {
    value = "${aws_subnet.vpc_private.*.id}"
}

output "public_subnet" {
    value = "${aws_subnet.vpc_public.*.id}"
}