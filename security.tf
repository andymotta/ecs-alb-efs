resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = "${aws_vpc.main.id}"
  name   = "${var.resource_tag}-ecs-lbsg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = "${aws_vpc.main.id}"
  name        = "${var.resource_tag}-ecs-instsg"

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidr_blocks = [
      "${var.admin_cidr_ingress}",
      "${var.cidr_block}",
    ]
  }
  ingress {
    protocol  = "TCP"
    from_port = 2049 #NFS for EFS
    to_port   = 2049
    self = true
  }
  ingress {
    protocol  = "tcp"
    from_port = 32768
    to_port   = 61000
    # Dynamic Port Range for Application Load Balancer
    security_groups = ["${aws_security_group.lb_sg.id}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "admin_cidr_ingress" {
  description = "Open SSH on instances to only this IP range"
}

variable "key_name" {
  description = "Key in AWS you would like to use to access you instances"
}
