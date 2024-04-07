# Set up the AWS provider with the desired region where the resources will be created
provider "aws" {
  region = "us-east-1"  # Eastern USA region for deploying the resources
}


# Define an Elastic Beanstalk application for the backend
resource "aws_elastic_beanstalk_application" "my_app" {
  name        = "Tic-tac-toe-backend-eb"  # Name of the application
  description = "Tic-tac-toe backend app"  # Description of what the application is
}


# Create an IAM instance profile for the Elastic Beanstalk environment to grant necessary permissions
resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "eb-tic-tac-toe-backend-instance-profile"  # Instance profile name
  role = "LabRole"  # Existing IAM role to associate with the instance profile
}


# Provision an S3 bucket to store the application's version source code
resource "aws_s3_bucket" "app_version_bucket" {
  bucket = "tic-tac-toe-backend-bucket"  # Name of the S3 bucket for storing application versions
}


# Upload the application's source code to the S3 bucket
resource "aws_s3_object" "app_version" {
  bucket = aws_s3_bucket.app_version_bucket.bucket  # Reference to the above-created S3 bucket
  key    = "myapp_backend_v1.zip"  # The object key within the S3 bucket (file name in the bucket)
  source = "myapp_backend_v1.zip"  # Local source file path to be uploaded to the S3 bucket
  etag   = filemd5("myapp_backend_v1.zip")  # MD5 hash of the file for change detection
}

# Define a version of the Elastic Beanstalk application using the uploaded S3 object
resource "aws_elastic_beanstalk_application_version" "my_version" {
  name        = "v1"  # Version label for the application version
  application = aws_elastic_beanstalk_application.my_app.name  # Link to the EB application defined above
  bucket      = aws_s3_bucket.app_version_bucket.bucket  # S3 bucket containing the source bundle
  key         = aws_s3_object.app_version.key  # File path in S3 bucket to the source bundle
}

# Create an Elastic Beanstalk environment for deploying the application version
resource "aws_elastic_beanstalk_environment" "my_env" {
  name                = "Tic-tac-toe-backend-env"  # Environment name within Elastic Beanstalk
  application         = aws_elastic_beanstalk_application.my_app.name  # Link to the EB application
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.0 running Docker"  # Platform for the environment
  version_label       = aws_elastic_beanstalk_application_version.my_version.name  # Version of the application to deploy

  # Configuration settings for the Elastic Beanstalk environment:
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"  # Environment type, could be LoadBalanced or SingleInstance
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"  # Minimum size of the Auto Scaling Group
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"  # Maximum size of the Auto Scaling Group
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name  # The IAM instance profile to use
  }
}