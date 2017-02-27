resource "aws_cloudwatch_log_group" "ecs" {
  name = "${var.resource_tag}-ecs-group/ecs-agent"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${var.resource_tag}-ecs-group/${element(split(",", var.container_name), count.index)}"
  count = "${length(split(",", var.container_name))}"
}
