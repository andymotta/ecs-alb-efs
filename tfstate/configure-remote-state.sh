#!/bin/sh
terraform remote config -backend=s3 -backend-config="bucket=ecs-alb-efs-terraform-state" -backend-config="key=${project}/terraform.tfstate" -backend-config="region=${region}" -backend-config="profile=${profile}"
