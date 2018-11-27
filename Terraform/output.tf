output "elb-dns"{

	value = "${aws_elb.gigsky-elb.dns_name}"

}