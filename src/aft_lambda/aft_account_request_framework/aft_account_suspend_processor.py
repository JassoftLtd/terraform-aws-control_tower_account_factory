# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
import inspect
import logging
import os
from time import sleep
from typing import TYPE_CHECKING, Any, Dict
from boto3.dynamodb.conditions import Key

from aft_common import notifications, sqs
from aft_common.account_provisioning_framework import ProvisionRoles
from aft_common.auth import AuthClient
from aft_common.logger import configure_aft_logger
from boto3.session import Session

if TYPE_CHECKING:
    from aws_lambda_powertools.utilities.typing import LambdaContext
else:
    LambdaContext = object

configure_aft_logger()
logger = logging.getLogger("aft")

workloads_ou = os.getenv("WORKLOADS_OU")
suspended_ou = os.getenv("SUSPENDED_OU")


def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> None:
    aft_management_session = Session()
    auth = AuthClient()

    print(f"Event {event}")

    for record in event["Records"]:

        new_image = record["dynamodb"]["NewImage"]
        account_email = new_image["control_tower_parameters"]["M"]["AccountEmail"]["S"]
        ddb_event_name = new_image["ddb_event_name"]["S"]

        # Only handle Removes
        if ddb_event_name != "REMOVE":
            continue

        try:
            ct_management_session = auth.get_ct_management_session(
                role_name=ProvisionRoles.SERVICE_ROLE_NAME
            )

            organizations_client = ct_management_session.client("organizations")

            # Lookup account_id
            paginator = organizations_client.get_paginator('list_accounts_for_parent')
            accounts = paginator.paginate(
                ParentId=workloads_ou
            )

            for page in accounts:
                account_id = any( account['Id'] for account in page["Accounts"] if account['Email'] == account_email)
                if account_id:
                    break

            if not account_id:
                raise Exception(f"Account {account_email} not found")


            # Stop resources
            # TODO: Work out how to stop the resources in the account

            # Close Account
            print(f"Closing account: {account_id}")
            organizations_client.close_account(
                AccountId=account_id
            )

            print(f"Account Closed, Waiting 10 seconds...")
            sleep(10)

            # Move Account
            print(f"Moving account: {account_id}")

            organizations_client.move_account(
                AccountId=account_id,
                SourceParentId=workloads_ou,
                DestinationParentId=suspended_ou,
            )

        except Exception as error:
            notifications.send_lambda_failure_sns_message(
                session=aft_management_session,
                message=str(error),
                context=context,
                subject="AFT account suspend failed",
            )
            message = {
                "FILE": __file__.split("/")[-1],
                "METHOD": inspect.stack()[0][3],
                "EXCEPTION": str(error),
            }
            logger.exception(message)
            raise




