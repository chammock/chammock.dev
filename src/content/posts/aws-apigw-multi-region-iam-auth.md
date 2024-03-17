+++
author = "Curtis Hammock"
title = "AWS API Gateway Multi-Region IAM Auth"
date = "2022-07-04"
lastmod ="2024-03-16"
description = "AWS API Gateway Multi-Region IAM Auth"
tags = [
    "aws",
    "api",
    "apigw",
    "iam",
    "auth"
]
+++
> **_Updates_**
> 
> **03/16/24** Updated the [Example](#example) section that separates an old vs new method to solve this problem. The old method is from the original publication and the new method is updated based on new AWS SDK features.
>
> **11/11/22** This information was only tested and confirmed on an API Gateway of type `REST`. Unfortunitly, as of today, it was confirmed that this method does not work with API Gateways of type `HTTP`.

---

## Overview

As you already know AWS API Gateway has the ability to secure your APIs using [IAM or Custom authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-control-access-to-api.html). With IAM auth, your caller will create and sign the request using [AWS SigV4](https://docs.aws.amazon.com/general/latest/gr/signing_aws_api_requests.html). AWS then takes and verifies that signature before allowing or denying access to your API Gateway. But what about when your API Gateway is deployed in multiple regions?

## Problem

The problem with IAM auth is that the AWS SigV4 signature requires a region. This leaves your IAM authed API Gateways restricted to a singular region with no option for disaster recovery or high availability. You may be thinking, couldn't the request be signed for one region but still used in another, unfortunately not. When you try submitting a request signed for one region to another, AWS returns a `"Credential should be scoped to a valid region, not 'xx'.` error. 


Now there were previous solutions, albeit hacky, around this problem. You could create an endpoint on your API that tells your calling client which region your active endpoint is in and which the request should be signed for. Or, you could use CloudFront with signed urls to front your APIs. Or, ... You get it, there are multiple other paths to go down to solve this issue, but ultimately API Gateway should have a native solution.


## Solution

The API Gateway native solution is to use AWS's newly introduced signature SigV4A (SigV4 Asymmetric). With AWS's release of [S3 Multi-Region Access Points](https://aws.amazon.com/s3/features/multi-region-access-points/), AWS uses a new method (SigV4A) of signing requests that target multiple regions vs singular regions as currently required by SigV4. You can find a better explanation of the differences between SigV4 and SigV4A over in [shufflesharding.com](https://shufflesharding.com/posts/aws-sigv4-and-sigv4a)'s post. As well, as of this writing there is no official AWS documentation on how to generate a SigV4A signed request, but digging through AWS's Boto3/Botocore SDK I was able to find the required methods to generate a SigV4A request for API Gateway. 

## Example

Below is an example using the AWS Python Boto3/Botocore SDK to execute a SigV4A signed request to an API Gateway. These API Gateways are deployed in both the `us-east-1` and `us-west-2` region fronted by the custom domain name `apigw-iam-auth-demo.chammock.cloud`. These API Gateways' resource policies allow all authenticated AWS principals to invoke it. You can try it for yourself by creating a signed SigV4A request, like below, against this domain and you will receive a response from either of the random regional API Gateways. If you want to see a failed response message, swap out the SigV4A signed request for a SigV4 signed request, which you should get the errored described in the [Problem](#problem) section above.

> **Note** SigV4A only makes sense when setting up an API Gateway with a custom domain name, otherwise each API Gateway has a unique invoke URL defeating the multi-region purpose. 
> You should expand upon this example by exploring AWS's SDKs to find the appropriate methods and parameters needed for your use case and language of choice.


### New method
This new method is built upon AWS's Common Runtime (CRT) Python example found [here](https://github.com/awslabs/aws-crt-python). 
```python
from botocore import awsrequest
from boto3.session import Session
from botocore.crt.auth import CrtSigV4AsymAuth
import requests

# Host and prepared Requests request
URL = 'https://apigw-iam-auth-demo.chammock.cloud/'
aws_request = requests.Request('GET', URL).prepare()

# Gather AWS Credentials & sign request 
creds = Session().get_credentials()
sigV4A = CrtSigV4AsymAuth(creds, 'execute-api',  'us-*')
request = awsrequest.AWSRequest(method='GET', url=URL)
sigV4A.add_auth(request)

# Replace the request headers to include new signed headers
aws_request.headers = dict(request.headers)

# Send request
session = requests.Session()
response = session.send(aws_request)
print(response.headers)
print(response.text)


```

### Old method
This older method was created when the article was first published. It is recommended to use the above [New Method](#new-method), but this method is left for reference.
```python
from botocore.session import Session
from botocore.compat import awscrt, urlsplit
import requests

# Host and prepared Requests request
HOST = 'apigw-iam-auth-demo.chammock.cloud'
aws_request = requests.Request('GET', f'https://{HOST}', headers={'host': HOST}).prepare()


# Gather AWS Credentials to sign request
frozen_credentials = Session().get_credentials().get_frozen_credentials()
credentials_provider = awscrt.auth.AwsCredentialsProvider.new_static(
    access_key_id=frozen_credentials.access_key,
    secret_access_key=frozen_credentials.secret_key,
    session_token=frozen_credentials.token
)

# Create a signing config used to sign the request
signing_config = awscrt.auth.AwsSigningConfig(
    algorithm=awscrt.auth.AwsSigningAlgorithm.V4_ASYMMETRIC, # New AWS SigV4A (Asymmetric)
    signature_type=awscrt.auth.AwsSignatureType.HTTP_REQUEST_HEADERS,
    credentials_provider=credentials_provider,
    region='us-*',  # Allows this request to be signed for any US region. Could also be * for all regions or comma separated list of specific regions
    service='execute-api'  # Required service name for signed API Gateway requests
)

# Create the required signing HttpHeaders/HttpRequest for the SigV4 signing method
crt_headers = awscrt.http.HttpHeaders(aws_request.headers.items())
url_parts = urlsplit(aws_request.url)
crt_path = url_parts.path if url_parts.path else '/'
crt_request = awscrt.http.HttpRequest(
    method=aws_request.method,
    path=crt_path,
    headers=crt_headers,
    body_stream=None,
)
# Sign the request and replace the request headers to include new signed headers
awscrt.auth.aws_sign_request(crt_request, signing_config).result()
aws_request.headers = dict(crt_request.headers)

# Send request
session = requests.Session()
response = session.send(aws_request)
print(response.text)

```


### Response
You should receive either of the following responses depending on which API Endpoint you got routed too. 
```json
{
  "message" : "us-west-2"
}

OR

{
  "message" : "us-east-1"
}
```