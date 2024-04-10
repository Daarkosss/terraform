# Configure the AWS provider with the specified region
provider "aws" {
  region = "us-east-1"  # The region where resources will be created
}


# Create an Elastic Beanstalk application resource
resource "aws_elastic_beanstalk_application" "my_app" {
  name        = "Tic-tac-toe-frontend-eb"  # The name of the Elastic Beanstalk application
  description = "Tic-tac-toe frontend app"  # Description of the application
}


# Define an IAM instance profile for the Elastic Beanstalk instance
resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "eb-tic-tac-toe-frontend-instance-profile"  # Name of the IAM instance profile
  role = "LabRole"  # The IAM role associated with the instance profile
}


# Create an S3 bucket to store the application versions
resource "aws_s3_bucket" "app_version_bucket" {
  bucket = "tic-tac-toe-frontend-bucket"  # Name of the S3 bucket
}


# Upload the application source code to the S3 bucket
resource "aws_s3_object" "app_version" {
  bucket = aws_s3_bucket.app_version_bucket.bucket  # Reference to the bucket created above
  key    = "myapp_frontend_v1.zip"  # The object key in S3 (the file name in the bucket)
  source = "myapp_frontend_v1.zip"  # Local path to the source zip file
  etag   = filemd5("myapp_frontend_v1.zip")  # MD5 hash of the file to detect changes
}


# Create an application version in Elastic Beanstalk
resource "aws_elastic_beanstalk_application_version" "my_version" {
  name        = "v1"  # Version label
  application = aws_elastic_beanstalk_application.my_app.name  # Link to the EB application
  bucket      = aws_s3_bucket.app_version_bucket.bucket  # S3 bucket containing the source bundle
  key         = aws_s3_object.app_version.key  # S3 object key of the source bundle
}


# Define an Elastic Beanstalk environment for the application
resource "aws_elastic_beanstalk_environment" "my_env" {
  name                = "Tic-tac-toe-frontend-env"  # Environment name
  application         = aws_elastic_beanstalk_application.my_app.name  # Link to the EB application
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.0 running Docker"  # Platform for the environment
  version_label       = aws_elastic_beanstalk_application_version.my_version.name  # Version to deploy

  # Elastic Beanstalk environment settings:
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"  # Environment type (e.g., SingleInstance, LoadBalanced)
  }

  # By setting MinSize and MaxSize, you define the scaling boundaries for environment, ensuring that it can automatically scale within these limits 
  # based on the performance requirements of your application. This helps in managing the cost while ensuring availability and performance.
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"  # Minimum size of the Auto Scaling group
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"  # Maximum size of the Auto Scaling group
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name  # IAM instance profile to use
  }

  # Environment variables for the application:
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "MY_APP_API_HOST"
    value     = "tic-tac-toe-backend-env.eba-dqskxeyt.us-east-1.elasticbeanstalk.com"  # Backend API host
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "MY_APP_API_PORT"
    value     = "80"  # Backend API port
  }
}
