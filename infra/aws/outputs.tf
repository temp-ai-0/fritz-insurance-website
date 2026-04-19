output "cloudfront_url" {
  description = "Live site URL via CloudFront"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name — used by the deploy script to sync files"
  value       = aws_s3_bucket.site.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used by the deploy script for cache invalidation"
  value       = aws_cloudfront_distribution.site.id
}
