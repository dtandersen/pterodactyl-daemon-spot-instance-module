provider "aws" {
  region = "${var.region}"
}

resource "aws_spot_instance_request" "cheap_worker" {
  ami           = "${data.aws_ami.centos.image_id}"
  instance_type = "c5.xlarge"
  key_name = "${var.key_name}"
  subnet_id = "${var.subnet_id}"
  vpc_security_group_ids  = ["${aws_security_group.allow_all.id}"]
  user_data = "${data.template_file.user_data.rendered}"
  associate_public_ip_address = true
  wait_for_fulfillment = true
  spot_type = "one-time"
  ebs_optimized = true
  
  root_block_device {
    volume_size = "30"
    volume_type = "gp2"
    delete_on_termination = true
  }

  tags {
    Name = "CheapWorker"
  }
  #depends_on = ["aws_internet_gateway.gw"]
}

data "aws_ami" "centos" {
  owners      = ["679593333241"]
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/firstboot.sh")}"

  vars {
    host = "${var.host}"
    email = "${var.email}"
    swap_size = "${var.swap_size}"
  }
}

data "aws_route53_zone" "selected" {
  name         = "${var.zone_name}."
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${var.host}"
  type    = "A"
  ttl     = "${var.ttl}"
  records = ["${aws_spot_instance_request.cheap_worker.public_ip}"]
}
