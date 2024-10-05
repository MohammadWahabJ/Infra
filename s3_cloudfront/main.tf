provider "aws" {
  region = "ap-south-1"  
}

# Create the S3 bucket
resource "aws_s3_bucket" "public_bucket" {
  bucket = "demo-test-bucket-m228yrghhwhab" 

  tags = {
    Name = "CloudFront-Bucket"
  }
}

# Block Public Access settings at the bucket level - allow public access
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.public_bucket.id

  block_public_acls       = false   # Allow public ACLs
  block_public_policy     = false   # Allow bucket policies that grant public access
  ignore_public_acls      = false   # Do not ignore public ACLs
  restrict_public_buckets = false   # Do not restrict public access
}

# Apply a bucket policy to allow public access to objects in the bucket
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.public_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",  
        Principal = "*",   
        Action = "s3:GetObject", 
        Resource = "${aws_s3_bucket.public_bucket.arn}/*"  
      }
    ]
  })
}








# CloudFront Origin Access Identity (OAI) to secure S3 bucket content
resource "aws_cloudfront_origin_access_identity" "s3_identity" {
  comment = "Allow CloudFront to access S3"
}


# Create the CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.public_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.public_bucket.id}"

    # Custom origin settings
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3_identity.cloudfront_access_identity_path
    }
  }

  enabled = true

  # Default Cache Behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.public_bucket.id}"

    viewer_protocol_policy = "allow-all"  # Allow both HTTP and HTTPS
    min_ttl                = 0
    default_ttl            = 3600  # 1 hour
    max_ttl                = 86400 # 1 day

    forwarded_values {
      query_string = false  # No query string forwarding
      cookies {
        forward = "none"    # No cookies forwarded
      }
    }
  }

  # Viewer Certificate - using the default CloudFront certificate
  viewer_certificate {
    cloudfront_default_certificate = true  # Use CloudFront's default SSL/TLS certificate
  }

  # Restrictions block - allows access from anywhere by default
  restrictions {
    geo_restriction {
      restriction_type = "none"  # No geographic restrictions
    }
  }

  price_class = "PriceClass_100"  # Use the cheapest CloudFront edge locations

  tags = {
    Name = "S3-to-CloudFront"
  }
}