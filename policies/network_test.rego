package foundations.network_test

import rego.v1

import data.foundations.network

sg_with(ingress) := {"resource_changes": [{
	"mode": "managed",
	"type": "aws_security_group",
	"address": "aws_security_group.web",
	"change": {"actions": ["create"], "after": {"ingress": ingress}, "after_unknown": {}},
}]}

test_https_from_world_passes if {
	count(network.deny) == 0 with input as sg_with([{"protocol": "tcp", "from_port": 443, "to_port": 443, "cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []}])
}

test_http_from_world_passes if {
	count(network.deny) == 0 with input as sg_with([{"protocol": "tcp", "from_port": 80, "to_port": 80, "cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []}])
}

test_ssh_from_world_is_denied if {
	result := network.deny with input as sg_with([{"protocol": "tcp", "from_port": 22, "to_port": 22, "cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []}])
	count(result) == 1
}

test_all_traffic_from_ipv6_world_is_denied if {
	result := network.deny with input as sg_with([{"protocol": "-1", "from_port": 0, "to_port": 0, "cidr_blocks": [], "ipv6_cidr_blocks": ["::/0"]}])
	count(result) == 1
}

test_port_range_from_world_is_denied if {
	result := network.deny with input as sg_with([{"protocol": "tcp", "from_port": 443, "to_port": 8443, "cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []}])
	count(result) == 1
}

test_ssh_from_private_range_passes if {
	count(network.deny) == 0 with input as sg_with([{"protocol": "tcp", "from_port": 22, "to_port": 22, "cidr_blocks": ["10.20.0.0/16"], "ipv6_cidr_blocks": []}])
}

test_vpc_ingress_rule_resource_is_checked if {
	result := network.deny with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_vpc_security_group_ingress_rule",
		"address": "aws_vpc_security_group_ingress_rule.rdp",
		"change": {"actions": ["create"], "after": {"cidr_ipv4": "0.0.0.0/0", "ip_protocol": "tcp", "from_port": 3389, "to_port": 3389}, "after_unknown": {}},
	}]}
	count(result) == 1
}

test_security_group_rule_egress_is_ignored if {
	count(network.deny) == 0 with input as {"resource_changes": [{
		"mode": "managed",
		"type": "aws_security_group_rule",
		"address": "aws_security_group_rule.out",
		"change": {"actions": ["create"], "after": {"type": "egress", "cidr_blocks": ["0.0.0.0/0"], "protocol": "-1", "from_port": 0, "to_port": 0}, "after_unknown": {}},
	}]}
}
