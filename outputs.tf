output "Message" {
  value = "Please wait a few minutes for health checks to turn positive"
}

output "ALB-Root" {
  value = "${aws_alb.main.dns_name}"
}

output "APIs-Under-ALB" {
  value = "${
    formatlist("Available path patterns: %s", aws_alb_target_group.api.health_check.*.path)}"
}
