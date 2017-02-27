resource "aws_alb_target_group" "web" {
  name     = "${var.resource_tag}-${element(split(",", var.container_name),0)}-ecs"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
  health_check {
    path = "/"
  }
}

resource "aws_alb_target_group" "api" {
  name     = "${var.resource_tag}-${element(split(",", var.container_name), count.index + 1 )}-ecs"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
  health_check {
    path = "/${element(split(",", var.health_check), count.index + 1 )}"
  }
  count = "${length(split(",", var.container_name)) -1 }"
}

resource "aws_alb" "main" {
  name            = "${var.resource_tag}-alb-ecs"
  internal        = "${var.internal_elb}"
  subnets         = ["${aws_subnet.public.*.id}"]
  security_groups = ["${aws_security_group.lb_sg.id}"]
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    target_group_arn = "${aws_alb_target_group.web.id}"
    type             = "forward"
  }
}

resource "aws_alb_listener_rule" "api" {
  listener_arn = "${aws_alb_listener.front_end.arn}"
  priority = "${count.index + 1}"
  action {
    type = "forward"
    target_group_arn = "${element(aws_alb_target_group.api.*.id, count.index + 1)}"
  }
  condition {
    field = "path-pattern"
    values = [
      "/${element(split(",", var.container_name), count.index + 1)}*"
    ]
  }
  count = "${length(split(",", var.container_name)) -1 }"
}
