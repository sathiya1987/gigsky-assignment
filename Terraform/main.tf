# Provisioning VPC resources in AWS 

provider aws
  { 
    region="${var.aws_region}"
    access_key="${var.aws_access_key}"
    secret_key="${var.aws_secret_key}"
    token ="${var.aws_token}"
 }
resource "aws_vpc" "stage" {
  cidr_block = "${var.vpc_cidr}
  tags {
        Name = "gigsky-vpc"
    }
}

#Provisioning Subnets resources in AWS 
resource "aws_subnet" "subnets" {
  count             = "${length(var.vpc_subnet_cidr)}"
  vpc_id            = "${aws_vpc.stage.id}"
  cidr_block        = "${element(var.vpc_subnet_cidr, count.index)}"
#  availability_zone = "${element(var.vpc_subnet_azs, count.index)}"

  tags {
    Name = "${element(var.vpc_subnet_names, count.index)}"
  }
}

#Provisioning IGW resources in AWS 
resource "aws_internet_gateway" "web-gigsky" {
    vpc_id = "${aws_vpc.stage.id}"
}

#Provisioning Route Tables resources in AWS 
resource "aws_route_table" "gigsky-route" {
  vpc_id = "${aws_vpc.stage.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.web-gigsky.id}"
  }
}

resource "aws_route_table_association" "subnets" {
  count          = "${length(var.vpc_subnet_cidr)}"
  subnet_id      = "${element(aws_subnet.subnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.gigsky-route.id}"
}

#Provisioning SG resources in AWS 
resource "aws_security_group" "websg" {

name = "security_group_for_web_server"
ingress {
	from_port = 80
	to_port = 80
	protocol = "tcp"
	cidr_blocks = ["192.0.0.0/24"]
}
ingress {
	from_port = 22
	to_port = 22
	protocol = "tcp"
	cidr_blocks = ["192.0.0.0/24"]
}
egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
   }
vpc_id ="${aws_vpc.stage.id}"
}

#Provisioning SG for ELB in AWS 
resource "aws_security_group" "elbsg" {

name = "security_group_for_elb"
ingress {
	from_port = 80
	to_port = 80
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
}

egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
vpc_id ="${aws_vpc.stage.id}"
}

#Provisioning Lanuch Configuration in AWS 

resource "aws_launch_configuration" "gigsky-lc" {
  image_id = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  security_groups = ["${aws_security_group.websg.id}"]
  key_name = "${var.key_name}"
  name = "gigsky-lc"

}

#Provisioning ASG  in AWS 
resource "aws_autoscaling_group" "gigsky-asg" {
  name = "gigsky-asg"
  max_size = 2
  min_size = 1
  desired_capacity = 1
  force_delete= true
  launch_configuration = "${aws_launch_configuration.gigsky-lc.name}"
  vpc_zone_identifier= ["${aws_subnet.subnets.*.id}"]
  health_check_grace_period = 300
  health_check_type = "ELB"
  enabled_metrics=["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
  metrics_granularity="1Minute"
  protect_from_scale_in="true"
  load_balancers = ["${aws_elb.gigsky-elb.id}"]
  tag {
    key="Name"
    value="gigsky-demo"
    propagate_at_launch = true
  }
tag {
    key="Env"
    value="Dev"
    propagate_at_launch = true
  }
  
  
 timeouts {
    create = "60m"
    delete = "2h"
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_policy" "up" {
  name = "gigsky-scaleout"
  scaling_adjustment = 3
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.gigsky-asg.name}"

}
resource "aws_autoscaling_policy" "down" {
  name = "gigsky-scalein"
  scaling_adjustment = -3
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.gigsky-asg.name}"
}
resource "aws_cloudwatch_metric_alarm" "high" {
    alarm_name = "gigsky-alarm-high"
    comparison_operator = "GreaterThanOrEqualToThreshold"

evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "90"
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.gigsky-asg.name}"
    }
    alarm_description = "This metric monitor ec2 cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.up.arn}"]

}
resource "aws_cloudwatch_metric_alarm" "low" {
    alarm_name = "gigsky-alarm-low"
    comparison_operator = "LessThanThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "40"
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.gigsky-asg.name}"
    }
    alarm_description = "This metric monitor ec2 cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.down.arn}"]

}

#Provisioning ELB  in AWS 

resource "aws_elb" "gigsky-elb" {
name = "gigsky-web-elb"
security_groups = ["${aws_security_group.elbsg.id}"]
subnets = ["${aws_subnet.subnets.*.id}"]
listener {
instance_port = 80
instance_protocol = "http"
lb_port = 80
lb_protocol = "http"
}
health_check {
healthy_threshold = 2
unhealthy_threshold = 2
timeout = 3
target = "HTTP:80/"
interval = 30
}
cross_zone_load_balancing = true
idle_timeout = 300
connection_draining = true
connection_draining_timeout = 300
tags {
Name ="gigsky-web-elb"
}

 timeouts {
    create = "60m"
    delete = "2h"
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_cookie_stickiness_policy" "cookie_stickness" {
name = "cookiestickness"
load_balancer = "${aws_elb.gigsky-elb.id}"
lb_port = 80
cookie_expiration_period = 600

#Fetching private ip address to adding into inventory file
provisioner "local-exec" {
    command = "echo ${aws_autoscaling_group.gigsky-asg.private_ip} >> /home/centos/playbooks/hosts"
  }

  provisioner "local-exec" {
	command = "ansible-playbook -i /home/centos/playbooks/hosts /home/centos/playbooks/site.yml --private-key=/home/centos/test.pem"
  }
}




