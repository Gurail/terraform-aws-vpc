################################################################################
# VPC
################################################################################
data "aws_region" "current" {}

resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = merge({
    "Name" = var.vpc_name
  }, var.tags)
}

################################################################################
# Route table
################################################################################
resource "aws_route_table" "rt" {
  for_each = { for rt in var.route_tables : rt.route_table_name => rt }
  vpc_id   = aws_vpc.vpc.id

  tags = merge({
    Name = each.key
  }, var.tags)
}

resource "aws_vpc_endpoint" "rt_s3_endpoint" {
  for_each          = length([ for rt in var.route_tables : rt if rt.enable_s3_endpoint ]) > 0 == true ? {"this"={}} : {}

  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
}

resource "aws_vpc_endpoint_route_table_association" "rt_s3_endpoint" {
  for_each        = { for rt in var.route_tables : rt.route_table_name => rt if rt.enable_s3_endpoint }
  route_table_id  = aws_route_table.rt[each.key].id
  vpc_endpoint_id = aws_vpc_endpoint.rt_s3_endpoint["this"].id
}

################################################################################
# Network ACL
################################################################################
resource "aws_network_acl" "nacl" {
  for_each = { for nacl in var.network_acls : nacl.network_acl_name => nacl }

  vpc_id = aws_vpc.vpc.id
  tags = merge({
    Name = each.key
  }, var.tags)
}

locals {
  inbound_nacls = flatten([for nacl in var.network_acls :
    lookup(nacl, "inbound_rules", null) != null ? [
      for rule in nacl.inbound_rules : {
        nacl_key        = nacl.network_acl_name
        rule_number     = rule.rule_number
        rule_action     = rule.rule_action
        from_port       = lookup(rule, "from_port", null)
        to_port         = lookup(rule, "to_port", null)
        icmp_code       = lookup(rule, "icmp_code", null)
        icmp_type       = lookup(rule, "icmp_type", null)
        protocol        = rule.protocol
        cidr_block      = lookup(rule, "cidr_block", null)
        ipv6_cidr_block = lookup(rule, "ipv6_cidr_block", null)
      }
    ] : []
  ])
  outbound_nacls = flatten([for nacl in var.network_acls :
    lookup(nacl, "outbound_rules", null) != null ? [
      for rule in nacl.outbound_rules : {
        nacl_key        = nacl.network_acl_name
        rule_number     = rule.rule_number
        rule_action     = rule.rule_action
        from_port       = lookup(rule, "from_port", null)
        to_port         = lookup(rule, "to_port", null)
        icmp_code       = lookup(rule, "icmp_code", null)
        icmp_type       = lookup(rule, "icmp_type", null)
        protocol        = rule.protocol
        cidr_block      = lookup(rule, "cidr_block", null)
        ipv6_cidr_block = lookup(rule, "ipv6_cidr_block", null)
      }
    ] : []
  ])
}

resource "aws_network_acl_rule" "nacl_inbound" {
  for_each = { for inbound_nacl in local.inbound_nacls : "${inbound_nacl.nacl_key}_${inbound_nacl.rule_number}" => inbound_nacl }

  network_acl_id = aws_network_acl.nacl[each.value.nacl_key].id

  egress          = false
  rule_number     = each.value.rule_number
  rule_action     = each.value.rule_action
  from_port       = each.value.from_port
  to_port         = each.value.to_port
  icmp_code       = each.value.icmp_code
  icmp_type       = each.value.icmp_type
  protocol        = each.value.protocol
  cidr_block      = each.value.cidr_block
  ipv6_cidr_block = each.value.ipv6_cidr_block
}

resource "aws_network_acl_rule" "nacl_outbound" {
  for_each = { for outbound_nacl in local.outbound_nacls : "${outbound_nacl.nacl_key}_${outbound_nacl.rule_number}" => outbound_nacl }

  network_acl_id = aws_network_acl.nacl[each.value.nacl_key].id

  egress          = true
  rule_number     = each.value.rule_number
  rule_action     = each.value.rule_action
  from_port       = each.value.from_port
  to_port         = each.value.to_port
  icmp_code       = each.value.icmp_code
  icmp_type       = each.value.icmp_type
  protocol        = each.value.protocol
  cidr_block      = each.value.cidr_block
  ipv6_cidr_block = each.value.ipv6_cidr_block
}

################################################################################
# Internet Gateway
################################################################################
resource "aws_internet_gateway" "igw" {
  for_each = var.enable_internet_gateway == true ? {"this"={}} : {}
  vpc_id   = aws_vpc.vpc.id

  tags = merge({
    Name = "igw-${var.vpc_name}"
  }, var.tags)
}

resource "aws_route" "route_igw" {
  for_each = { for rt in var.route_tables : rt.route_table_name => rt if rt.enable_public_route }

  route_table_id         = aws_route_table.rt[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw["this"].id
}



################################################################################
# Subnets
################################################################################
resource "aws_subnet" "subnets" {
  for_each = { for subnet in var.subnets : subnet.subnet_name => subnet }

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge({
    "Name" = each.key
  }, var.tags)

  depends_on = [
    aws_route_table.rt
  ]
}

resource "aws_route_table_association" "rt_subnet_assoc" {
  for_each       = { for subnet in var.subnets : "${subnet.route_table_key}-${subnet.subnet_name}" => subnet if subnet.route_table_key != null }
  subnet_id      = aws_subnet.subnets[each.value.subnet_name].id
  route_table_id = aws_route_table.rt[each.value.route_table_key].id
}

resource "aws_network_acl_association" "nacl_subnet_assoc" {
  for_each       = { for subnet in var.subnets : "${subnet.network_acl_key}_${subnet.subnet_name}" => subnet if subnet.network_acl_key != null }
  subnet_id      = aws_subnet.subnets[each.value.subnet_name].id
  network_acl_id = aws_network_acl.nacl[each.value.network_acl_key].id

}

################################################################################
# Nat gateway
################################################################################
resource "aws_eip" "ngw" {
  for_each = { for ngw in var.nat_gateways : ngw.ngw_name => ngw }
  domain   = "vpc"

  tags = var.tags
}

resource "aws_nat_gateway" "ngw" {
  for_each      = { for ngw in var.nat_gateways : ngw.ngw_name => ngw }
  allocation_id = aws_eip.ngw[each.key].id
  subnet_id     = aws_subnet.subnets[each.value.subnet_key].id

  tags = merge({
    Name = each.key
  }, var.tags)

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw, aws_subnet.subnets]
}

resource "aws_route" "route_ngw" {
  for_each = { for ngw in var.nat_gateways : ngw.ngw_name => ngw if ngw.route_table_key != null }

  route_table_id         = aws_route_table.rt[each.value.route_table_key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw[each.key].id
}
