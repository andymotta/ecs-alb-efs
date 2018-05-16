data "aws_caller_identity" "current" {}

resource "aws_iam_role" "application" {
  name = "${var.resource_tag}"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ecs.amazonaws.com",
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "application" {
  name = "${var.resource_tag}"
  role = "${aws_iam_role.application.name}"

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

resource "aws_iam_policy_attachment" "aws_managed" {
  count      = "${var.add_aws_policy ? 1 : 0}"
  name       = "${var.aws_policy}"
  roles      = ["${aws_iam_role.application.name}"]
  policy_arn = "arn:aws:iam::aws:policy/${var.aws_policy}"
}

resource "aws_iam_instance_profile" "ec2" {
  name  = "${var.resource_tag}"
  role = "${aws_iam_role.ec2.name}"
}

resource "aws_iam_role" "ec2" {
  name = "${var.resource_tag}-ec2"

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
  template = "${file("${path.module}/templates/instance-profile-policy.json")}"
  vars {
    log_group_arn = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${var.resource_tag}/*"
  }
}
resource "aws_iam_role_policy" "ec2" {
  name   = "${var.resource_tag}-ec2"
  role   = "${aws_iam_role.ec2.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}
