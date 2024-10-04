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
