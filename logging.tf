resource "aws_cloudwatch_log_group" "ecs" {
  name = "${var.resource_tag}"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${var.resource_tag}/${element(split(",", var.container_name), count.index)}"
  count = "${length(split(",", var.container_name))}"
}
