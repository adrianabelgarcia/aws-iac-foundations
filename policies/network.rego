package foundations.network

import rego.v1

import data.foundations.helpers

# Only HTTP and HTTPS may be open to the internet. Everything else must be reached through
# a load balancer, a bastion or a private path, and must not use 0.0.0.0/0 or ::/0 as a source.

world_cidrs := {"0.0.0.0/0", "::/0"}

public_port_allowed(protocol, from_port, to_port) if {
	protocol in {"tcp", "6"}
	from_port == to_port
	from_port in {80, 443}
}

# Ingress rules from the three shapes Terraform AWS resources use, normalised into one form.
ingress_rules contains rule if {
	some rc in helpers.resources_of_type("aws_security_group")
	some r in helpers.as_list(rc.change.after.ingress)
	rule := {
		"address": rc.address,
		"cidrs": array.concat(helpers.as_list(r.cidr_blocks), helpers.as_list(r.ipv6_cidr_blocks)),
		"protocol": r.protocol,
		"from_port": r.from_port,
		"to_port": r.to_port,
	}
}

ingress_rules contains rule if {
	some rc in helpers.resources_of_type("aws_security_group_rule")
	rc.change.after.type == "ingress"
	rule := {
		"address": rc.address,
		"cidrs": array.concat(helpers.as_list(rc.change.after.cidr_blocks), helpers.as_list(rc.change.after.ipv6_cidr_blocks)),
		"protocol": rc.change.after.protocol,
		"from_port": rc.change.after.from_port,
		"to_port": rc.change.after.to_port,
	}
}

ingress_rules contains rule if {
	some rc in helpers.resources_of_type("aws_vpc_security_group_ingress_rule")
	rule := {
		"address": rc.address,
		"cidrs": [c | some k in ["cidr_ipv4", "cidr_ipv6"]; c := rc.change.after[k]; c != null],
		"protocol": rc.change.after.ip_protocol,
		"from_port": rc.change.after.from_port,
		"to_port": rc.change.after.to_port,
	}
}

deny contains msg if {
	some rule in ingress_rules
	some cidr in rule.cidrs
	cidr in world_cidrs
	not public_port_allowed(rule.protocol, rule.from_port, rule.to_port)
	msg := sprintf("%s: ingress from %s on protocol %v, ports %v-%v is not allowed; only tcp/80 and tcp/443 may be open to the internet", [rule.address, cidr, rule.protocol, rule.from_port, rule.to_port])
}
