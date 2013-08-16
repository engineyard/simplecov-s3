# Simplecov-S3

Sample Usage:

Gemile

    group :test do
      gem 'simplecov-s3'
    end

config/environment.rb

    require File.expand_path('../application', __FILE__)

    if Rails.env.test?
      require File.expand_path("../../spec/coverage_helper", __FILE__)
    end

spec/coverage_helper.rb

    unless ENV["SKIP_COVERAGE"]
      require 'simplecov'
      SimpleCov.start(:rails)
      SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
      SimpleCov.at_exit do
        SimpleCov.result.format!
      end
      # Yes this is a hack, the most reliable way to ensure that simplecov doesn't de-dupe your coverage results for having the same command_name: "rspec"
      SimpleCov.command_name("HAX#{Time.now.to_i}")
      SimpleCov.merge_timeout 86400
    end

Rakefile (basic, 1 build unit)

    if defined?(RSpec) #don't load this task in production

      require 'simplecov-s3'

      task :spec_with_coverage do
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
          :bucket_name => "somebucket",
          :public_url_base => "http://somebucket.s3-website-us-east-1.amazonaws.com/",
          :assets_url => "http://somebucket.s3-website-us-east-1.amazonaws.com/assets",
          :shared_secret => "XXXXXXXXXXXX", #used so build units can find each other, and for covereage postback
          :postback_url => "https://bot.example.org/coverage",
        )
        #ensure coverage is pushed regardless of build result
        SimpleCov::S3.ensured("spec") do
          cov.push_full
        end
      end

      task :default => :spec_with_coverage
    end

Rakefile (advanced, merge build units across worker boxes)

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
      #debug => true means publish readable HTML for each partial coverage report (as opposed to just RAW JSON)
      cov.push_partial(:debug => true)
      cov.pull_merge_and_push_full
    end

.gitinore:

    #ignore generated coverage results
    coverage

Sample S3 Bucket policy to allow the "\<user\>" user of from the Amazon Account ID "\<awsaccount\>" access to read/write from the "\<bucket\>" bucket, while the public is allowed read-only:

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
