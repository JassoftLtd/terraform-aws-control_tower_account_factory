# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
data "local_file" "version" {
  filename = "${path.module}/VERSION"
}

data "local_file" "python_version" {
  filename = "${path.module}/PYTHON_VERSION"
}

data "aws_ssm_parameters_by_path" "servicecatalog_regional_data" {
  count = data.aws_partition.current.partition == "aws" ? 1 : 0
  path  = "/aws/service/global-infrastructure/services/servicecatalog/regions"
}

data "aws_service" "home_region_validation" {
  service_id = "controltower"
  lifecycle {
    precondition {
      condition     = try(contains(data.aws_ssm_parameters_by_path.servicecatalog_regional_data[0].values, var.ct_home_region), true) == true
      error_message = "AFT is not supported on Control Tower home region ${var.ct_home_region}. Refer to https://docs.aws.amazon.com/controltower/latest/userguide/limits.html for more information."
    }
  }
}

data "aws_partition" "current" {
}

data "aws_organizations_organization" "aft_organization" {
  provider = aws.ct_management
}

data "aws_organizations_organizational_units" "aft_organization_root_ou" {
  provider  = aws.ct_management
  parent_id = data.aws_organizations_organization.aft_organization.roots[0].id
}

data "aws_organizations_organizational_units" "aft_suspended_ou" {
  provider  = aws.ct_management
  name      = "Suspended"
  parent_id = data.aws_organizations_organization.aft_organization.roots[0].id
}