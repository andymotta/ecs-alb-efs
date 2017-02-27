resource "aws_s3_bucket" "terraform" {
    bucket = "${var.bucket_name}"
    acl = "authenticated-read"
    region = "${var.aws_region}"
    tags {
        Name = "${var.resource_tag} Terraform State"
    }
}

data "terraform_remote_state" "s3" {
    backend = "s3"
    config {
        bucket = "${aws_s3_bucket.terraform.id}"
        key = "${var.resource_tag}/terraform.tfstate"
        region = "${var.aws_region}"
    }
}
