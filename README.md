# Simplecov-S3

Sample Usage:

config/environment.rb

    require File.expand_path('../application', __FILE__)

    if Rails.env.test?
      require File.expand_path("../../spec/coverage_helper", __FILE__)
    end

coverage_helper.rb

    unless ENV["SKIP_COVERAGE"]
      require 'simplecov'
      SimpleCov.start(:rails)
      SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
      SimpleCov.at_exit do
        SimpleCov.result.format!
      end
      SimpleCov.command_name("HAX#{Time.now.to_i}")
      SimpleCov.merge_timeout 86400
    end

Rakefile

    task :coverage do
      build_units = YAML.load_file(File.expand_path("../build_units.yml",__FILE__)).size
      require File.expand_path("../spec/coverage_helper", __FILE__)
      cov = SimpleCov::S3.new(
        :fog => {
          :provider => 'AWS',
          :aws_access_key_id => "XXXXXX",
          :aws_secret_access_key => "XXXXXXXXXXXXX",
          :region => "us-east-1",
        },
        :project_name => ENV["TRAVIS_REPO_SLUG"],
        :build_id => ENV["TRAVIS_BUILD_ID"],
        :job_id => ENV["TRAVIS_JOB_ID"],
        :build_unit => ENV["BUILD_UNIT"],
        :build_units => build_units,
        :bucket_name => "somebucket",
        :public_url_base => "http://somebucket.s3-website-us-east-1.amazonaws.com/",
        :assets_url => "http://somebucket.s3-website-us-east-1.amazonaws.com/assets",
        :shared_secret => "XXXXXXXXXXXX", #used so build units can find each other, and for covereage postback
        :postback_url => "https://bot.example.org/coverage",
      )
      cov.push_partial(:debug => true)
      cov.pull_merge_and_push_full
    end

Sample S3 Bucket policy to allow the "<user>" user of from the Amazon Account ID "<awsaccount>" access to read/write from the "<bucket>" bucket, while the public is allowed read-only:

    {
      "Version": "2008-10-17",
      "Id": "Policy123456",
      "Statement": [
        {
          "Sid": "Stmt11111",
          "Effect": "Allow",
          "Principal": {
            "AWS": "arn:aws:iam::<awsaccount>:user/<user>"
          },
          "Action": "s3:*",
          "Resource": "arn:aws:s3:::<bucket>"
        },
        {
          "Sid": "Stmt222222",
          "Effect": "Allow",
          "Principal": {
            "AWS": "arn:aws:iam::<awsaccount>:user/<user>"
          },
          "Action": "s3:*",
          "Resource": "arn:aws:s3:::<bucket>/*"
        },
        {
          "Sid": "Stmt33333",
          "Effect": "Allow",
          "Principal": {
            "AWS": "*"
          },
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::<bucket>/*"
        }
      ]
    }
