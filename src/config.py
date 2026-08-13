"""Sensitive runtime config, read from an SSM SecureString parameter.

The parameter holds a JSON object so several secrets can share one parameter
and one API call. Its value is set outside of Terraform.
"""

import json
import os
from functools import cache

import boto3

ssm = boto3.client("ssm")

CONFIG_SSM_PARAM_NAME = os.environ["CONFIG_SSM_PARAM_NAME"]


@cache
def get_config() -> dict:
    """Return the decrypted config, fetched once per execution environment.

    Warm invocations reuse the cached value; a container recycle picks up a
    rotated secret.
    """
    response = ssm.get_parameter(Name=CONFIG_SSM_PARAM_NAME, WithDecryption=True)
    return json.loads(response["Parameter"]["Value"])
