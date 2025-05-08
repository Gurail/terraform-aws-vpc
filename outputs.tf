output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.vpc.arn
}

output "subnets_map" {
  description = "Map of subnet attributes keyed by subnet name"
  value = aws_subnet.subnets
}

output "route_tables_map" {
  description = "Map of route table attributes keyed by route table name"
  value = aws_route_table.rt
}

output "nat_gateways_map" {
  description = "Map of NAT gateway attributes keyed by NAT gateway name"
  value = aws_nat_gateway.ngw
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = length(aws_internet_gateway.igw) == 1 ? aws_internet_gateway.igw["this"].id : null
}

output "s3_endpoint" {
  description = "The S3 VPC endpoint ID"
  value       = length(aws_vpc_endpoint.rt_s3_endpoint) == 1 ? aws_vpc_endpoint.rt_s3_endpoint["this"].id : null
  
}