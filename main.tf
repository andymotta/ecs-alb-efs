# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

## EC2

### Network

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

resource "aws_vpc" "main" {
  cidr_block = "${var.cidr_block}"
  enable_dns_hostnames = "true"
  tags {
    Name = "${aws_ecs_cluster.main.name}"
  }
}

resource "aws_subnet" "main" {
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "a" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.main.*.id, count.index)}"
  route_table_id = "${aws_route_table.r.id}"
}

### Compute

resource "aws_autoscaling_group" "app" {
  name                 = "${var.resource_tag}-ecs-asg"
  vpc_zone_identifier  = ["${aws_subnet.main.*.id}"]
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
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    aws_region         = "${var.aws_region}"
    ecs_cluster_name   = "${aws_ecs_cluster.main.name}"
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = "${aws_cloudwatch_log_group.ecs.name}"
    efs_id = "${aws_efs_file_system.ecs_efs.id}"
  }
}

data "aws_ami" "stable_coreos" {
  most_recent = true

  filter {
    name   = "description"
    values = ["CoreOS stable *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"] # CoreOS
}

resource "aws_launch_configuration" "app" {
  security_groups = [
    "${aws_security_group.instance_sg.id}",
  ]

  key_name                    = "${var.key_name}"
  image_id                    = "${data.aws_ami.stable_coreos.id}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.app.name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  associate_public_ip_address = true
  name = "${var.resource_tag}-ecs-lc"
  lifecycle {
    create_before_destroy = true
  }
}

### Security

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

## EFS
resource "aws_efs_file_system" "ecs_efs" {
  tags {
    Name = "${aws_ecs_cluster.main.name}-ecs"
  }
}

resource "aws_efs_mount_target" "ecs_efs_target" {
  count             = "${var.az_count}"
  file_system_id = "${aws_efs_file_system.ecs_efs.id}"
  subnet_id      = "${element(aws_subnet.main.*.id, count.index)}"
  security_groups = ["${aws_security_group.instance_sg.id}"]
}

## ECS

resource "aws_ecs_cluster" "main" {
  name = "${var.resource_tag}"
}

data "template_file" "task_definition" {
  template           = "${file("${path.module}/task-definition.json")}"
  vars {
    image_url        = "${var.ecr_account}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.namespace}/${element(split(",", var.container_name), count.index)}:${element(split(",", var.version_tag), count.index)}"
    container_name   = "${element(split(",", var.container_name), count.index)}"
    log_group_region = "${var.aws_region}"
    log_group_name   = "${element(aws_cloudwatch_log_group.app.*.name, count.index)}"
    containerPort    = "${element(split(",", var.container_port), count.index)}"
    alb              = "${aws_alb.main.dns_name}"
  }
  count = "${length(split(",", var.container_name))}"
}

resource "aws_ecs_task_definition" "td" {
  family                = "${var.resource_tag}_${element(split(",", var.container_name), count.index)}"
  container_definitions = "${element(data.template_file.task_definition.*.rendered, count.index)}"
  volume {
  name = "efs"
  host_path = "/mnt/${element(split(",", var.container_name), count.index)}"
  }
  count = "${length(split(",", var.container_name))}"
}

resource "aws_ecs_service" "web" {
  name            = "${var.resource_tag}-ecs-${element(split(",", var.container_name),0)}"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${element(aws_ecs_task_definition.td.*.arn, 0)}"
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
    "aws_alb_listener.front_end",
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
    "aws_alb_listener.front_end",
  ]
  count = "${length(split(",", var.container_name)) -1}"
}

## IAM

resource "aws_iam_role" "ecs_service" {
  name = "${var.resource_tag}_ecs_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "${var.resource_tag}_ecs_policy"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "app" {
  name  = "${var.resource_tag}-ecs-instprofile"
  roles = ["${aws_iam_role.app_instance.name}"]
}

resource "aws_iam_role" "app_instance" {
  name = "${var.resource_tag}-ecs-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = "${file("${path.module}/instance-profile-policy.json")}"
  vars {
    log_group_arn = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${var.resource_tag}-ecs-group/*"
  }
}
resource "aws_iam_role_policy" "instance" {
  name   = "${var.resource_tag}-EcsInstanceRole"
  role   = "${aws_iam_role.app_instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

## ALB

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
    path = "/${element(split(",", var.container_name), count.index + 1 )}"
  }
  count = "${length(split(",", var.container_name)) -1 }"
}

resource "aws_alb" "main" {
  name            = "${var.resource_tag}-alb-ecs"
  subnets         = ["${aws_subnet.main.*.id}"]
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

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "ecs" {
  name = "${var.resource_tag}-ecs-group/ecs-agent"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${var.resource_tag}-ecs-group/${element(split(",", var.container_name), count.index)}"
  count = "${length(split(",", var.container_name))}"
}
