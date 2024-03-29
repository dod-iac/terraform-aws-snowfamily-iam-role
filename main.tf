/**
 * ## Usage
 *
 * Creates an IAM role for use as a Snow Family service role.
 *
 * ```hcl
 * module "snowfamily_iam_role" {
 *   source = "dod-iac/snowfamily-iam-role/aws"
 *
 *   name                  = format("app-%s-snowfamily-%s", var.application, var.environment)
 *   kms_keys_decrypt      = ["*"]
 *   kms_keys_encrypt      = ["*"]
 *   s3_buckets_import     = ["*"]
 *   s3_buckets_export     = ["*"]
 *   sns_topics_publish    = ["*"]
 *   tags               = {
 *     Application = var.application
 *     Environment = var.environment
 *     Automation  = "Terraform"
 *   }
 * }
 * ```
 *
 *
 * ## Terraform Version
 *
 * Terraform 0.13. Pin module version to ~> 1.0.0 . Submit pull-requests to main branch.
 *
 * Terraform 0.11 and 0.12 are not supported.
 *
 * ## License
 *
 * This project constitutes a work of the United States Government and is not subject to domestic copyright protection under 17 USC § 105.  However, because the project utilizes code licensed from contributors and other third parties, it therefore is licensed under the MIT License.  See LICENSE file for more information.
 */

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

#
# IAM
#

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "importexport.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = var.name
  assume_role_policy = length(var.assume_role_policy) > 0 ? var.assume_role_policy : data.aws_iam_policy_document.assume_role_policy.json
  tags               = var.tags
}

data "aws_iam_policy_document" "main" {

  #
  # KMS / DecryptObjects
  #

  dynamic "statement" {
    for_each = length(var.kms_keys_decrypt) > 0 ? [1] : []
    content {
      sid = "DecryptObjects"
      actions = [
        "kms:ListAliases",
        "kms:Decrypt",
      ]
      effect    = "Allow"
      resources = var.kms_keys_decrypt
    }
  }

  #
  # KMS / EncryptObjects
  #

  dynamic "statement" {
    for_each = length(var.kms_keys_encrypt) > 0 ? [1] : []
    content {
      sid = "EncryptObjects"
      actions = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*"
      ]
      effect    = "Allow"
      resources = var.kms_keys_encrypt
    }
  }

  #
  # S3 / ListBucket
  #

  dynamic "statement" {
    for_each = length(distinct(var.s3_buckets_export)) > 0 && length(distinct(flatten([var.s3_buckets_import, var.s3_buckets_export]))) > 0 ? [1] : []
    content {
      sid = "ListBucket"
      actions = [
        "s3:GetBucketLocation",
        "s3:GetBucketRequestPayment",
        "s3:GetEncryptionConfiguration",
        "s3:ListBucket",
      ]
      effect = "Allow"
      resources = sort(distinct(flatten([
        var.s3_buckets_import,
        var.s3_buckets_export
      ])))
    }
  }

  dynamic "statement" {
    for_each = length(distinct(var.s3_buckets_export)) == 0 && length(distinct(var.s3_buckets_import)) > 0 ? [1] : []
    content {
      sid = "ListBucket"
      actions = [
        "s3:GetBucketLocation",
        "s3:GetBucketRequestPayment",
        "s3:GetEncryptionConfiguration",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
      ]
      effect    = "Allow"
      resources = sort(distinct(var.s3_buckets_import))
    }
  }

  #
  # S3 / GetObject
  #

  dynamic "statement" {
    for_each = length(var.s3_buckets_export) > 0 ? [1] : []
    content {
      sid = "GetObject"
      actions = [
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:GetObjectVersion",
      ]
      effect    = "Allow"
      resources = formatlist("%s/*", var.s3_buckets_export)
    }
  }

  #
  # S3 / ListBucketMultipartUploads
  #

  dynamic "statement" {
    for_each = length(distinct(var.s3_buckets_export)) > 0 && length(distinct(var.s3_buckets_import)) > 0 ? [1] : []
    content {
      sid = "ListBucketMultipartUploads"
      actions = [
        "s3:ListBucketMultipartUploads",
      ]
      effect    = "Allow"
      resources = sort(distinct(var.s3_buckets_import))
    }
  }

  #
  # S3 / PutObject
  #

  dynamic "statement" {
    for_each = length(distinct(var.s3_buckets_import)) > 0 ? [1] : []
    content {
      sid = "PutObject"
      actions = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ]
      effect    = "Allow"
      resources = formatlist("%s/*", sort(distinct(var.s3_buckets_import)))
    }
  }

  #
  # SNS / Publish
  #

  dynamic "statement" {
    for_each = length(var.sns_topics_publish) > 0 ? [1] : []
    content {
      sid = "Publish"
      actions = [
        "sns:Publish"
      ]
      effect    = "Allow"
      resources = var.sns_topics_publish
    }
  }
}

resource "aws_iam_policy" "main" {
  count = length(var.s3_buckets_import) > 0 || length(var.s3_buckets_export) > 0 || length(var.sns_topics_publish) > 0 ? 1 : 0

  name        = length(var.policy_name) > 0 ? var.policy_name : format("%s-policy", var.name)
  description = length(var.policy_description) > 0 ? var.policy_description : format("The policy for %s.", var.name)
  policy      = data.aws_iam_policy_document.main.json
}

resource "aws_iam_role_policy_attachment" "main" {
  count = length(var.s3_buckets_import) > 0 || length(var.s3_buckets_export) > 0 || length(var.sns_topics_publish) > 0 ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.main.0.arn
}
