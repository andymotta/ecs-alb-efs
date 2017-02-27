resource "aws_ecs_cluster" "main" {
  name = "${var.resource_tag}"
}

data "template_file" "task_definition" {
  template           = "${file("${path.module}/templates/task-definition.json")}"
  vars {
    image_url        = "${var.registry_url}${element(split(",", var.namespace), count.index)}${element(split(",", var.container_name), count.index)}:${element(split(",", var.version_tag), count.index)}"
    container_name   = "${element(split(",", var.container_name), count.index)}"
    log_group_region = "${var.aws_region}"
    log_group_name   = "${element(aws_cloudwatch_log_group.app.*.name, count.index)}"
    containerPort    = "${element(split(",", var.container_port), count.index)}"
    alb              = "${aws_alb.main.dns_name}"
    name             = "${var.env_key}"
    value            = "${var.env_value}"

  }
  count = "${length(split(",", var.container_name))}"
}


resource "aws_ecs_task_definition" "td" {
  family                = "${var.resource_tag}_${element(split(",", var.container_name), count.index)}"
  container_definitions = "${element(data.template_file.task_definition.*.rendered, count.index)}"
  task_role_arn =  "${aws_iam_role.ecs_service.arn}"
  volume {
  name = "efs"
  host_path = "/mnt/efs/${element(split(",", var.container_name), count.index)}"
  }
  count = "${length(split(",", var.container_name))}"
}

resource "aws_ecs_service" "web" {
  name            = "${var.resource_tag}-ecs-${element(split(",", var.container_name),0)}"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${element(aws_ecs_task_definition.td.*.arn,0)}"
  desired_count   = "${element(split(",", var.desired_count),0)}"
  deployment_minimum_healthy_percent = 50
  iam_role        = "${aws_iam_role.ecs_service.name}"
  load_balancer {
    target_group_arn = "${aws_alb_target_group.web.id}"
    container_name   = "${element(split(",", var.container_name),0)}"
    container_port   = "${element(split(",", var.container_port),0)}"
  }
  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_iam_role_policy.instance",
    "aws_alb_listener.front_end"
  ]
}

resource "aws_ecs_service" "api" {
  name            = "${var.resource_tag}-ecs-${element(split(",", var.container_name), count.index + 1)}"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${element(aws_ecs_task_definition.td.*.arn, count.index + 1 )}"
  desired_count   = "${element(split(",", var.desired_count), count.index + 1)}"
  deployment_minimum_healthy_percent = 50
  iam_role        = "${aws_iam_role.ecs_service.name}"
  load_balancer {
    target_group_arn = "${element(aws_alb_target_group.api.*.id, count.index)}"
    container_name   = "${element(split(",", var.container_name), count.index + 1)}"
    container_port   = "${element(split(",", var.container_port), count.index + 1)}"
  }
  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_iam_role_policy.instance",
    "aws_alb_listener.front_end"
  ]
  count = "${length(split(",", var.container_name)) -1}"
}
