output "Message" {
  value = "Please wait a few minutes for health checks to turn positive"
}

output "ALB-Root" {
  value = "${aws_alb.main.dns_name}"
}
