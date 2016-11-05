output "product-web" {
  value = "${aws_alb.main.dns_name}"
}
output "product-api" {
  value = "${aws_alb.main.dns_name}/products"
}
