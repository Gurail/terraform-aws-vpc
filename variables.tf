################################################################################
# VPC
################################################################################
variable "vpc_name" {
  description = "Name of the VPC."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The IPv4 CIDR block for the VPC."
  type        = string

  validation {
    condition     = length(var.vpc_cidr_block) >= 10 && length(var.vpc_cidr_block) <= 18
    error_message = "CIDR block length must be between 10 and 18 characters."
  }
}


################################################################################
# Internet Gateway
################################################################################
variable "enable_internet_gateway" {
  description = "Create internet gateway to VPC"
  type        = bool
  default     = false
}


################################################################################
# Route tables
################################################################################
variable "route_tables" {
  description = <<-EOF
    List of Route tables to create.

    `route_table_name` - Name of the route table
    `enable_public_route` - (Optional) Create 0.0.0.0/0 route with destination to internet gateway. enable_internet_gateway need to set true.
    `enable_s3_endpoint` - (Optional) Associate route table to vpc s3 endpoint.
  EOF
  type = list(object({
    route_table_name    = string
    enable_public_route = optional(bool, false)
    enable_s3_endpoint  = optional(bool, false)
  }))

  default = []
}

################################################################################
# Network ACLs
################################################################################
variable "network_acls" {
  description = <<-EOF
    List of Network ACLs to create.

    `network_acl_name` - Name of the Network ACLS
    `inbound_rules` - List of inbound rules created under a Network ACL.
    `outbound_rules` - List of outbound rules created under a Network ACL.
  EOF
  type = list(object({
    network_acl_name = string
    inbound_rules = optional(list(object({
      rule_number     = string
      rule_action     = string
      from_port       = optional(string, null)
      to_port         = optional(string, null)
      icmp_code       = optional(string, null)
      icmp_type       = optional(string, null)
      protocol        = string
      cidr_block      = optional(string, null)
      ipv6_cidr_block = optional(string, null)
    })))
    outbound_rules = optional(list(object({
      rule_number     = string
      rule_action     = string
      from_port       = optional(string, null)
      to_port         = optional(string, null)
      icmp_code       = optional(string, null)
      icmp_type       = optional(string, null)
      protocol        = string
      cidr_block      = optional(string, null)
      ipv6_cidr_block = optional(string, null)
    })))
  }))
  default = []
}

################################################################################
# Subnets
################################################################################
variable "subnets" {
  description = <<-EOF
    List of VPC subnets to create.

    `subnet_name` - Name of the subnet
    `cidr_block` - The CIDR block for the subnet.
    `availability_zone` - The AZ for the subnet.
    `network_acl_key` - (Optional) Network ACL to associate with the subnet.
    `route_table_key` - (Optional) Route table to associate with the subnet.
  EOF
  type = list(object({
    subnet_name       = string
    cidr_block        = string
    availability_zone = string
    network_acl_key   = optional(string, null)
    route_table_key   = optional(string, null)
  }))

  default = []
}


################################################################################
# Nat gateways
################################################################################
variable "nat_gateways" {
  description = <<-EOF
    List of VPC subnets to create.

    `ngw_name` - Name of the Nat Gateway
    `subnet_key` - The Subnet ID of the subnet in which to place the NAT Gateway.
    `route_table_key` - (Optional) Create 0.0.0.0/0 route with destination to nat gateway to the supplied route table.
  EOF
  type = list(object({
    ngw_name        = string
    subnet_key      = string
    route_table_key = optional(string, null)
  }))

  default = []
}

################################################################################
# Flow Logs
################################################################################
variable "enable_flow_log" {
  description = "Enable flow log within VPC"
  type        = bool
}

variable "flow_log_destination_type" {
  description = "The type of the logging destination."
  type        = string
  default     = "cloud-watch-logs"

  validation {
    condition     = contains(["cloud-watch-logs", "s3", "kinesis-data-firehose"], var.flow_log_destination_type)
    error_message = "flow_log_destination_type value can only be cloud-watch-logs, s3, or kinesis-data-firehose."
  }
}

variable "enable_flow_log_destination_group_name" {
  description = "DEPRECATED soon only set true for backward compatibility with existing resource. Enable flow log to use log_group_name instead of log_destination."
  type        = bool
  default     = false
}

variable "flow_log_destination_arn" {
  description = "The ARN of the CloudWatch log group or S3 bucket where VPC Flow Logs will be pushed. If this ARN is a S3 bucket the appropriate permissions need to be set on that bucket's policy. When create_flow_log_cloudwatch_log_group is set to false this argument must be provided"
  type        = string
  default     = ""
}

variable "flow_log_log_format" {
  description = "The fields to include in the flow log record. Accepted format example: $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport}"
  type        = string
  default     = null
}

variable "flow_log_deliver_cross_account_role" {
  description = "ARN of the IAM role that allows Amazon EC2 to publish flow logs across accounts."
  type        = string
  default     = null
}

variable "flow_log_traffic_type" {
  description = "The type of traffic to capture. Valid values: ACCEPT, REJECT, ALL"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type value can only be ACCEPT, REJECT, or ALL."
  }
}

variable "flow_log_max_aggregation_interval" {
  description = "The maximum interval of time during which a flow of packets is captured and aggregated into a flow log record. Valid Values: `60` seconds or `600` seconds"
  type        = number
  default     = 600

  validation {
    condition     = contains([60, 600], var.flow_log_max_aggregation_interval)
    error_message = "flow_log_max_aggregation_interval value can only be `60` seconds or `600` seconds."
  }
}

variable "flow_log_file_format" {
  description = "The format for the flow log. Valid values: `plain-text`, `parquet`"
  type        = string
  default     = "plain-text"

  validation {
    condition     = contains(["plain-text", "parquet"], var.flow_log_file_format)
    error_message = "flow_log_file_format value can only be plain-text, or parquet."
  }
}

variable "flow_log_hive_compatible_partitions" {
  description = "Indicates whether to use Hive-compatible prefixes for flow logs stored in Amazon S3"
  type        = bool
  default     = false
}

variable "flow_log_per_hour_partition" {
  description = "Indicates whether to partition the flow log per hour. This reduces the cost and response time for queries"
  type        = bool
  default     = false
}

################################################################################
# Flow Log CloudWatch
################################################################################
variable "create_flow_log_cloudwatch_log_group" {
  description = "Whether to create CloudWatch log group for VPC Flow Logs"
  type        = bool
  default     = true
}

variable "create_flow_log_cloudwatch_iam_role" {
  description = "Whether to create IAM role for VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_log_cloudwatch_log_group_name" {
  description = "Specifies the name of CloudWatch Log Group for VPC flow logs"
  type        = string
  default     = null
}

variable "flow_log_cloudwatch_log_group_retention_in_days" {
  description = "Specifies the number of days you want to retain log events in the specified log group for VPC flow logs"
  type        = number
  default     = null
}

variable "flow_log_cloudwatch_log_group_kms_key_id" {
  description = "The ARN of the KMS Key to use when encrypting log data for VPC flow logs"
  type        = string
  default     = null
}

variable "flow_log_cloudwatch_log_group_skip_destroy" {
  description = " Set to true if you do not wish the log group (and any logs it may contain) to be deleted at destroy time, and instead just remove the log group from the Terraform state"
  type        = bool
  default     = false
}

variable "flow_log_cloudwatch_log_group_class" {
  description = "Specified the log class of the log group. Possible values are: STANDARD or INFREQUENT_ACCESS"
  type        = string
  default     = null
}

variable "vpc_flow_log_iam_role_name" {
  description = "Name to use on the VPC Flow Log IAM role created"
  type        = string
  default     = "vpc-exp-flow-log-role"
}

variable "flow_log_cloudwatch_iam_role_arn" {
  description = "The ARN for the IAM role that's used to post flow logs to a CloudWatch Logs log group. When flow_log_destination_arn is set to ARN of Cloudwatch Logs, this argument needs to be provided"
  type        = string
  default     = ""
}

variable "flow_log_cloudwatch_iam_role_conditions" {
  description = "Additional conditions of the CloudWatch role assumption policy"
  type = list(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  default = []
}

variable "vpc_flow_log_permissions_boundary" {
  description = "The ARN of the Permissions Boundary for the VPC Flow Log IAM Role"
  type        = string
  default     = null
}

variable "vpc_flow_log_iam_policy_name" {
  description = "Name of the IAM policy"
  type        = string
  default     = "vpc-exp-iam-policy"
}

################################################################################
# Tags
################################################################################
variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
