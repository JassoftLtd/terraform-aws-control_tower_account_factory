# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
resource "aws_codepipeline" "aft_codestar_customizations_destroy_codepipeline" {
  count    = local.vcs.is_codecommit ? 0 : 1
  name     = "${var.account_id}-customizations-destroy-pipeline"
  role_arn = data.aws_iam_role.aft_codepipeline_customizations_role.arn

  artifact_store {
    location = data.aws_s3_bucket.aft_codepipeline_customizations_bucket.id
    type     = "S3"

    encryption_key {
      id   = data.aws_kms_alias.aft_key.arn
      type = "KMS"
    }
  }

    provisioner "local-exec" {
    command = <<EOT
export AWS_PROFILE=aft-management; \

aws codepipeline stop-pipeline-execution \
  --pipeline-name "${var.account_id}-customizations-destroy-pipeline" \
  --pipeline-execution-id $( \
    aws codepipeline list-pipeline-executions \
      --pipeline-name "${var.account_id}-customizations-destroy-pipeline" \
    | jq -r '.pipelineExecutionSummaries[].pipelineExecutionId' \
  )
EOT
  }

  ##############################################################
  # Source
  ##############################################################
  stage {
    name = "Source"

    action {
      name             = "aft-global-customizations"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source-aft-global-customizations"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codestar_connection_arn.value
        FullRepositoryId     = data.aws_ssm_parameter.aft_global_customizations_repo_name.value
        BranchName           = data.aws_ssm_parameter.aft_global_customizations_repo_branch.value
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }

    action {
      name             = "aft-account-customizations"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source-aft-account-customizations"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codestar_connection_arn.value
        FullRepositoryId     = data.aws_ssm_parameter.aft_account_customizations_repo_name.value
        BranchName           = data.aws_ssm_parameter.aft_account_customizations_repo_branch.value
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  # ##############################################################
  # # Apply-AFT-Global-Customizations
  # ##############################################################
  #
  # stage {
  #   name = "AFT-Global-Customizations"
  #
  #   action {
  #     name            = "Apply"
  #     category        = "Build"
  #     owner           = "AWS"
  #     provider        = "CodeBuild"
  #     input_artifacts = ["source-aft-global-customizations"]
  #     version         = "1"
  #     run_order       = "2"
  #     configuration = {
  #       ProjectName = var.aft_global_customizations_terraform_codebuild_name
  #       EnvironmentVariables = jsonencode([
  #         {
  #           name  = "VENDED_ACCOUNT_ID",
  #           value = var.account_id,
  #           type  = "PLAINTEXT"
  #         }
  #       ])
  #     }
  #   }
  #
  # }

  ##############################################################
  # Apply-AFT-Account-Customizations
  ##############################################################

  stage {
    name = "AFT-Account-Customizations-Destroy"
    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = var.aft_account_customizations_destroy_terraform_codebuild_name
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
}
