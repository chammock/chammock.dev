+++
author = "Curtis Hammock"
title = "AWS Auth JWT Exchange"
date = "2023-10-06"
tags = [
    "aws",
    "api",
    "apigw",
    "iam",
    "auth",
    "jwt",
    "kms"
]
+++


The outcome is a demonstration of using an AWS API Gateway, KMS, and Lambda to exchange a Sigv4/Sigv4a signed request for a JSON Web Token (JWT). An exchange for a JWT helps AWS native workloads interact with external services using a common JWT authentication method without the need to manage static credentials. 

> On Nov 19, 2025 AWS released - [AWS IAM enables identity federation to external services using JSON Web Tokens (JWTs)](https://aws.amazon.com/about-aws/whats-new/2025/11/aws-iam-identity-federation-external-services-jwts/) which could replace the need for a custom JWT exchange mentioned on this page, for certain situations.


## References
- [Project Github Repo](https://github.com/chammock/aws-auth-jwt-exchange)
- AWS API Gateway IAM Auth
  - [REST API](https://docs.aws.amazon.com/apigateway/latest/developerguide/permissions.html)
  - [HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-access-control-iam.html)
- [AWS API Gateway IAM Auth Context](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-mapping-template-reference.html#context-variable-reference)
- [AWS KMS Asymetric Keys](https://docs.aws.amazon.com/kms/latest/developerguide/symmetric-asymmetric.html)
- [JSON Web Token (JWT) RFC](https://www.rfc-editor.org/rfc/rfc7797)
