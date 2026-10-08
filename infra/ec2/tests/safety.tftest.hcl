mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["ap-southeast-1a"] }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }
}

variables {
  stage              = "dev"
  provision_role_arn = "arn:aws:iam::123456789012:role/disaster-party-dev-provision"
  operator_ipv4_cidr = "203.0.113.10/32"
  ssh_key_name       = "test-key"
  domain             = "server.permees.com"
}

run "network_and_runtime_boundaries" {
  command = plan
  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh.cidr_ipv4 == "203.0.113.10/32" && aws_vpc_security_group_ingress_rule.ssh.from_port == 22
    error_message = "SSH must remain scoped to the operator."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.game.ip_protocol == "udp" && aws_vpc_security_group_ingress_rule.game.from_port == 29810 && aws_vpc_security_group_ingress_rule.game.to_port == 29811
    error_message = "Only the two allocated gameplay UDP ports may be exposed."
  }
  assert {
    condition     = aws_instance.game.metadata_options[0].http_tokens == "required" && aws_instance.game.root_block_device[0].encrypted
    error_message = "Require IMDSv2 and encrypted storage."
  }
  assert {
    condition     = aws_iam_role.runtime.name == "disaster-party-dev-runtime" && aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "Stage runtime role must not gain provisioning privileges."
  }
  assert {
    condition     = strcontains(aws_instance.game.user_data, "--rooms 2 --players 4") && strcontains(aws_instance.game.user_data, "KillMode=mixed") && strcontains(aws_instance.game.user_data, "response_header_timeout 20s")
    error_message = "Preserve room caps, graceful allocator shutdown and proxy timeout."
  }
}

run "stage_isolation" {
  command = plan
  variables {
    stage  = "staging"
    domain = "server-staging.permees.com"
  }
  assert {
    condition     = aws_iam_role.runtime.name == "disaster-party-staging-runtime" && aws_security_group.game.name == "disaster-party-staging" && output.room_service_url == "https://server-staging.permees.com"
    error_message = "Distinct stages must have distinct resource names and endpoints."
  }
}

run "reject_open_ssh" {
  command = plan
  variables {
    operator_ipv4_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.operator_ipv4_cidr]
}

run "reject_shell_in_domain" {
  command = plan
  variables {
    domain = "server.permees.com;echo unsafe"
  }
  expect_failures = [var.domain]
}
