resource "aws_autoscaling_group" "app" {
  name                 = "${var.resource_tag}-ecs-asg"
  vpc_zone_identifier  = ["${aws_subnet.private.*.id}"]
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  desired_capacity     = "${var.asg_desired}"
  launch_configuration = "${aws_launch_configuration.app.name}"
  depends_on           = ["aws_efs_mount_target.ecs_efs_target"]
  tag {
    key = "Name"
    value = "${var.resource_tag}-ecs-asg"
    propagate_at_launch = true
  }
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/templates/cloud-config.yml")}"
  vars {
    efs_id = "${aws_efs_file_system.ecs_efs.id}"
    aws_region = "${var.aws_region}"
    ecs_cluster = "${aws_ecs_cluster.main.name}"
  }
}

data "aws_ami" "amazon_ecs_optimized" {
  most_recent = true
  filter {
    name   = "name"
    values = ["*amazon-ecs-optimized"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["591542846629"] # Amazon
}

resource "aws_launch_configuration" "app" {
  security_groups = [
    "${aws_security_group.instance_sg.id}",
  ]

  key_name                    = "${var.key_name}"
  image_id                    = "${data.aws_ami.amazon_ecs_optimized.id}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.app.name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  lifecycle {
    create_before_destroy = true
    ignore_changes = ["image_id"]
  }
}
