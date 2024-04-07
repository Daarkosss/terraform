provider "aws" {
  region = "us-east-1"
}

resource "aws_elastic_beanstalk_application" "my_app" {
  name        = "Tic-tac-toe-frontend-eb"
  description = "Tic-tac-toe frontend app"
}

resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "eb-tic-tac-toe-frontend-instance-profile"
  role = "LabRole"
}

resource "aws_s3_bucket" "app_version_bucket" {
  bucket = "tic-tac-toe-frontend-bucket"
}

resource "aws_s3_object" "app_version" {
  bucket = aws_s3_bucket.app_version_bucket.bucket
  key    = "myapp_frontend_v1.zip"
  source = "myapp_frontend_v1.zip" 
  etag   = filemd5("myapp_frontend_v1.zip")
}

resource "aws_elastic_beanstalk_application_version" "my_version" {
  name        = "v1"
  application = aws_elastic_beanstalk_application.my_app.name
  bucket      = aws_s3_bucket.app_version_bucket.bucket
  key         = aws_s3_object.app_version.key
}

resource "aws_elastic_beanstalk_environment" "my_env" {
  name                = "Tic-tac-toe-frontend-env"
  application         = aws_elastic_beanstalk_application.my_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.0 running Docker"
  version_label       = aws_elastic_beanstalk_application_version.my_version.name

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "MY_APP_API_HOST"
    value     = "tic-tac-toe-backend-env.eba-dqskxeyt.us-east-1.elasticbeanstalk.com"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "MY_APP_API_PORT"
    value     = "80"
  }
}
