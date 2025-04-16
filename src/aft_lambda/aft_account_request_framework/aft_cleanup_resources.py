# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
import inspect
import logging
import os
from time import sleep
from typing import TYPE_CHECKING, Any, Dict

import aft_common.aft_utils as utils
from aft_common import codepipeline, ddb
from aft_common.auth import AuthClient
from aft_common.constants import SSM_PARAM_AFT_DDB_META_TABLE
from aft_common.logger import configure_aft_logger
from aft_common.notifications import send_lambda_failure_sns_message
from aft_common.organizations import OrganizationsAgent
from aft_common.ssm import get_ssm_parameter_value

if TYPE_CHECKING:
    from aws_lambda_powertools.utilities.typing import LambdaContext
else:
    LambdaContext = object


configure_aft_logger()
logger = logging.getLogger("aft")

workloads_ou = os.getenv("WORKLOADS_OU")
suspended_ou = os.getenv("SUSPENDED_OU")


def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> None:
    try:
        auth = AuthClient()
        aft_management_session = auth.get_aft_management_session()

        logger.info(f"Event: {event}")

        account_request = event["account_request"]
        account_email = account_request[
            "id"
        ]  # the account email is stored in "id" field

        logger.info(f"Beginnning resource cleanup for {account_email}")

        orgs_agent = OrganizationsAgent(
            ct_management_session=auth.get_ct_management_session()
        )

        # Can NOT use known-OU optimization here as request OU may be different
        # from existing OU
        account_id = orgs_agent.get_account_id_from_email(email=account_email)

        # Stop resources
        logger.info(f"Destroying resources for account {account_email}")
        codepipeline_client = aft_management_session.client("codepipeline", config=utils.get_high_retry_botoconfig())

        pipeline_name = codepipeline.get_pipeline_for_account(
            session=aft_management_session,
            account_id=account_id,
            destroy_pipeline=True
        )

        pipeline_response = codepipeline_client.start_pipeline_execution(name=pipeline_name)

        while True:
            execution_response = codepipeline_client.get_pipeline_execution(
                pipelineName=pipeline_name,
                pipelineExecutionId=pipeline_response['pipelineExecutionId']
            )
            status = execution_response['pipelineExecution']['status']

            if status == "Succeeded":
                break
            elif status in ["Failed", "Cancelled", "Stopped", "Stopping", "Superseded"]:
                raise Exception(
                    f"Pipeline execution {execution_response['pipelineExecution']['pipelineExecutionId']} failed with status {status}")
            else:
                sleep(10)  # Wait 10 seconds and check again

        # Delete pipelines
        logger.info(f"Deleting account customization pipeline for {account_id}")
        try:
            codepipeline.delete_customization_pipeline(
                aft_management_session=aft_management_session, account_id=account_id
            )
            logger.info(f"Customization pipeline deleted")

            codepipeline.delete_customization_pipeline(
                aft_management_session=aft_management_session, account_id=account_id, destroy_pipeline=True
            )
            logger.info(f"Customization destroy pipeline deleted")
        except Exception as e:
            logger.info(f"Customization pipeline not found")

        aft_request_metadata_table_name = get_ssm_parameter_value(
            aft_management_session,
            SSM_PARAM_AFT_DDB_META_TABLE,
        )

        logger.info(f"Deleting account metadata record for {account_id}")
        ddb.delete_ddb_item(
            session=aft_management_session,
            table_name=aft_request_metadata_table_name,
            primary_key={"id": account_id},
        )
        logger.info(f"Account metadata record deleted")

        # Close Account
        account_id.close_account(
            account_id=account_id
        )

        print(f"Account Closed, Waiting 10 seconds...")
        sleep(10)

        # Move Account
        account_id.move_account(
            account_id=account_id,
            from_ou=workloads_ou,
            to_ou=suspended_ou,
        )

        logger.info(f"Cleanup for {account_id} complete ")

    except Exception as error:
        send_lambda_failure_sns_message(
            session=aft_management_session,
            message=str(error),
            context=context,
            subject="AFT account request failed",
        )
        message = {
            "FILE": __file__.split("/")[-1],
            "METHOD": inspect.stack()[0][3],
            "EXCEPTION": str(error),
        }
        logger.exception(message)
        raise
