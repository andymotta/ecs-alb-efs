# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.profile}"
}
