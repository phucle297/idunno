variable "stage" {
  type        = string
  description = "One stage per state key and preferably per AWS account. Only create the playtest stage now."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.stage)
    error_message = "Stage must be dev, staging or prod."
  }
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "provision_role_arn" {
  type        = string
  description = "Existing stage-specific operator role to assume; never the EC2 runtime role."
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+", var.provision_role_arn))
    error_message = "Provide a valid AWS IAM role ARN."
  }
}

variable "operator_ipv4_cidr" {
  type        = string
  description = "Operator public IPv4 /32; never allow SSH from the entire Internet."
  validation {
    condition     = can(cidrnetmask(var.operator_ipv4_cidr)) && endswith(var.operator_ipv4_cidr, "/32")
    error_message = "SSH access must be one valid IPv4 /32."
  }
}

variable "ssh_key_name" {
  type        = string
  description = "Existing EC2 key-pair name in this region. Private keys never enter Terraform."
}

variable "domain" {
  type        = string
  description = "Stage-specific hostname; DNS is managed at Spaceship, outside this module."
  validation {
    condition     = can(regex("^[a-z0-9]+([.-][a-z0-9]+)*\\.[a-z]{2,}$", var.domain))
    error_message = "Use a lowercase DNS hostname without URLs, spaces or shell syntax."
  }
}

variable "ami_id" {
  type        = string
  default     = null
  description = "Pin the tested Ubuntu 24.04 x86_64 AMI after the initial plan; null selects latest Canonical image."
}
