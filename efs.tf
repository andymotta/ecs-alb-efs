resource "aws_efs_file_system" "ecs_efs" {
  tags {
    Name = "${aws_ecs_cluster.main.name}-ecs"
  }
}

resource "aws_efs_mount_target" "ecs_efs_target" {
  count             = "${var.az_count}"
  file_system_id = "${aws_efs_file_system.ecs_efs.id}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  security_groups = ["${aws_security_group.instance_sg.id}"]
}
