data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name = var.domain
}

resource "aws_s3_bucket" "primary" {
  bucket = local.name
}

resource "aws_s3_bucket_ownership_controls" "primary" {
  bucket = aws_s3_bucket.primary.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "primary" {
  bucket = aws_s3_bucket.primary.bucket
  policy = jsonencode({
    "Version" : "2008-10-17",
    "Id" : "PolicyForCloudFrontPrivateContent",
    "Statement" : [
      {
        "Sid" : "AllowCloudFrontServicePrincipalGet",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : "s3:GetObject",
        "Resource" : "${aws_s3_bucket.primary.arn}/public/*",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" : "${aws_cloudfront_distribution.this.arn}"
          }
        }
      },
      {
        "Sid" : "AllowCloudFrontServicePrincipalList",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : "s3:ListBucket",
        "Resource" : [
          "${aws_s3_bucket.primary.arn}",
        ],
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" : "${aws_cloudfront_distribution.this.arn}"
          },
          "StringLike" : {
            "s3:Prefix" : "public/*"
          }
        }
      }
    ]
  })
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = local.name
  description                       = "Access to ${local.name} Buckets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "this" {
  name = "Managed-CachingOptimizedForUncompressedObjects"
}

data "aws_cloudfront_origin_request_policy" "this" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_response_headers_policy" "this" {
  name = "Managed-CORS-with-preflight-and-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  comment             = "${local.name} Website"
  default_root_object = "index.html"
  aliases             = [local.name]
  viewer_certificate {
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    acm_certificate_arn            = aws_acm_certificate.this.arn
    minimum_protocol_version       = "TLSv1.2_2021"
  }
  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }
  origin {
    origin_id                = local.name
    domain_name              = aws_s3_bucket.primary.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_path              = "/public"
    origin_shield {
      enabled              = true
      origin_shield_region = data.aws_region.current.name
    }
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = local.name
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = false
    cache_policy_id            = data.aws_cloudfront_cache_policy.this.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.this.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.this.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
    }
  }
}

resource "aws_cloudfront_function" "this" {
  name    = replace(local.name, ".", "_")
  runtime = "cloudfront-js-1.0"
  comment = "${local.name} URL Rewrite"
  publish = true
  code    = file("${path.module}/cloudfront_function.js")
}


resource "aws_acm_certificate" "this" {
  domain_name       = local.name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "website" {
  zone_id = var.cloudflare_zone_id
  name    = local.name
  value   = aws_cloudfront_distribution.this.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "cert" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  ttl     = 60
}
