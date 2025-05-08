locals {
  create_flow_log_cloudwatch_iam_role  = var.enable_flow_log && var.flow_log_destination_type != "s3" && var.create_flow_log_cloudwatch_iam_role
  create_flow_log_cloudwatch_log_group = var.enable_flow_log && var.flow_log_destination_type != "s3" && var.create_flow_log_cloudwatch_log_group

  flow_log_destination_arn        = local.create_flow_log_cloudwatch_log_group && !var.enable_flow_log_destination_group_name && var.flow_log_destination_arn == "" ? try(aws_cloudwatch_log_group.flow_log["flow_log"].arn, null) : var.flow_log_destination_arn != "" ? var.flow_log_destination_arn : null
  flow_log_destination_group_name = local.create_flow_log_cloudwatch_log_group && var.enable_flow_log_destination_group_name ? try(aws_cloudwatch_log_group.flow_log["flow_log"].name, null) : null
  flow_log_iam_role_arn           = var.flow_log_destination_type != "s3" && local.create_flow_log_cloudwatch_iam_role && var.flow_log_cloudwatch_iam_role_arn == "" ? try(aws_iam_role.vpc_flow_log_cloudwatch["vpc_flow_log_cloudwatch"].arn, null) : var.flow_log_cloudwatch_iam_role_arn
}

################################################################################
# Flow Log
################################################################################

resource "aws_flow_log" "flow_log" {
  for_each = var.enable_flow_log ? { "flow_log" = {} } : {}

  log_destination_type       = var.flow_log_destination_type
  log_destination            = local.flow_log_destination_arn
  log_group_name             = local.flow_log_destination_group_name
  log_format                 = var.flow_log_log_format
  iam_role_arn               = local.flow_log_iam_role_arn
  deliver_cross_account_role = var.flow_log_deliver_cross_account_role
  traffic_type               = var.flow_log_traffic_type
  vpc_id                     = aws_vpc.vpc.id
  max_aggregation_interval   = var.flow_log_max_aggregation_interval

  dynamic "destination_options" {
    for_each = var.flow_log_destination_type == "s3" ? [true] : []

    content {
      file_format                = var.flow_log_file_format
      hive_compatible_partitions = var.flow_log_hive_compatible_partitions
      per_hour_partition         = var.flow_log_per_hour_partition
    }
  }

  tags = var.tags
}


################################################################################
# Flow Log CloudWatch
################################################################################

resource "aws_cloudwatch_log_group" "flow_log" {
  for_each = local.create_flow_log_cloudwatch_log_group ? { "flow_log" = {} } : {}

  name              = var.flow_log_cloudwatch_log_group_name != null ? var.flow_log_cloudwatch_log_group_name : "${var.vpc_name}-flowlogs"
  retention_in_days = var.flow_log_cloudwatch_log_group_retention_in_days
  kms_key_id        = var.flow_log_cloudwatch_log_group_kms_key_id
  skip_destroy      = var.flow_log_cloudwatch_log_group_skip_destroy
  log_group_class   = var.flow_log_cloudwatch_log_group_class

  tags = var.tags
}

data "aws_iam_policy_document" "flow_log_cloudwatch_assume_role" {
  for_each = local.create_flow_log_cloudwatch_iam_role ? { "flow_log_cloudwatch_assume_role" = {} } : {}

  statement {
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    effect = "Allow"

    actions = ["sts:AssumeRole"]

    dynamic "condition" {
      for_each = var.flow_log_cloudwatch_iam_role_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

resource "aws_iam_role" "vpc_flow_log_cloudwatch" {
  for_each = local.create_flow_log_cloudwatch_iam_role ? { "vpc_flow_log_cloudwatch" = {} } : {}

  name                 = var.vpc_flow_log_iam_role_name
  assume_role_policy   = data.aws_iam_policy_document.flow_log_cloudwatch_assume_role["flow_log_cloudwatch_assume_role"].json
  permissions_boundary = var.vpc_flow_log_permissions_boundary

  tags = var.tags
}

resource "aws_iam_role_policy" "vpc_flow_log_cloudwatch" {
  for_each = local.create_flow_log_cloudwatch_iam_role ? { "vpc_flow_log_cloudwatch" = {} } : {}

  name = "root"
  role = aws_iam_role.vpc_flow_log_cloudwatch["vpc_flow_log_cloudwatch"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
