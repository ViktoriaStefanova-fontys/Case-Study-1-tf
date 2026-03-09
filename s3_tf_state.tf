# # creation of bucket
# resource "aws_s3_bucket" "terraform_state_s3" {
#   bucket = var.terraform_state_bucket_name

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# # enabling versioning of bucket
# resource "aws_s3_bucket_versioning" "versioning_s3" {
#   bucket = aws_s3_bucket.terraform_state_s3.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }