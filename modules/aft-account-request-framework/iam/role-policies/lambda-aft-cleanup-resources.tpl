{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:DeleteItem"
            ],
            "Resource": [
                "arn:${data_aws_partition_current_partition}:dynamodb:${data_aws_region_aft-management_name}:${data_aws_caller_identity_aft-management_account_id}:table/${aws_dynamodb_table_aft-request-metadata_name}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codepipeline:ListPipelineExecutions",
                "codepipeline:ListPipelines",
                "codepipeline:ListTagsForResource",
                "codepipeline:GetPipelineExecution",
                "codepipeline:DeletePipeline",
                "codepipeline:StartPipelineExecution"
            ],
            "Resource": [
                "arn:${data_aws_partition_current_partition}:codepipeline:${data_aws_region_aft-management_name}:${data_aws_caller_identity_aft-management_account_id}:*"
            ]
        },
        {
            "Effect": "Allow",
			"Action": [
				"organizations:CloseAccount",
				"organizations:MoveAccount"
			],
			"Resource": [
				"*"
			]
        },
        {
            "Effect": "Allow",
            "Action": "ssm:GetParameter",
            "Resource": [
                "arn:${data_aws_partition_current_partition}:ssm:${data_aws_region_aft-management_name}:${data_aws_caller_identity_aft-management_account_id}:parameter/aft/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": [
                "arn:${data_aws_partition_current_partition}:iam::${data_aws_caller_identity_aft-management_account_id}:role/AWSAFTAdmin"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "sts:GetCallerIdentity",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": [
                "${aws_sns_topic_aft_notifications_arn}",
                "${aws_sns_topic_aft_failure_notifications_arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:GenerateDataKey",
                "kms:Encrypt",
                "kms:Decrypt"
            ],
            "Resource": [
                "${aws_kms_key_aft_arn}",
                "arn:${data_aws_partition_current_partition}:kms:${data_aws_region_aft-management_name}:${data_aws_caller_identity_aft-management_account_id}:alias/aws/sns"
            ]
        }
    ]
}
