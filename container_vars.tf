# container vars
variable "registry_url" {
  description = "Docker Registry URL to use for this deployment.  Blank will default to Public Docker Hub Registry"
  default = "048844758804.dkr.ecr.us-west-2.amazonaws.com/"
}
variable "namespace" {
  description = "Docker image namespace to use for this deployment. Blank namespace for official docker images (library). For user repositories you need namespace/"
  default = "microservices/,microservices/"
}
variable "container_name" {
  description = "Docker image container names in a csv list"
  default = "product-web,products"
}
variable "container_port" {
  description = "Application port inside of container[i]"
  default = "8000,8001"
}
variable "desired_count" {
  description = "Desired number of containers running for each service"
  default = "2,2"
}
variable "version_tag" {
  description = "Docker image version tag to use for this deployment in a csv ist"
  default = "latest,latest"
}
variable "health_check" {
  description = "ALB Health-Check for Microservice, Defaults to /"
  default = ",products"
}
variable "env_key" {
  description = "Additional environment variable key of value to set in containers.  Cannot be blank"
  default = "key"
}
variable "env_value" {
  description = "Additional environment variable value of key to set in containers.  Cannot be blank"
  default = "value"
}

variable "add_aws_policy" {
  description = "Attach additional Managed Policy to the ECS service?"
  default = false
}
variable "aws_policy" {
  description = "AWS Manged Policy to attach to ECS service, e.g. AmazonDynamoDBReadOnlyAccess"
  default = ""
}
