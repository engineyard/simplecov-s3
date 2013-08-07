require 'simplecov-s3'
require 'rspec'
require 'pry'

describe SimpleCov::S3 do

  it "is just barely tested" do
    Fog.mock!
    def Excon.post(*args)
      puts "Mocked!"
    end
    #TODO: generate some coverage data via SimpleCov.start ?
    fog_opts = {
        :provider => 'AWS',
        :aws_access_key_id => "XXXXXX",
        :aws_secret_access_key => "XXXXXXXXXXXXX",
        :region => "us-east-1",
      }
    s3conn = Fog::Storage.new(fog_opts)
    s3conn.directories.create(:key => "somebucket")
    cov_opts = {
      :fog => fog_opts,
      :project_name => "ey/simplecov-s3", #ENV["TRAVIS_REPO_SLUG"],
      :build_id => "123", #ENV["TRAVIS_BUILD_ID"],
      :job_id => "456", #ENV["TRAVIS_JOB_ID"],
      :build_unit => "5", #ENV["BUILD_UNIT"],
      :build_units => 2,
      :bucket_name => "somebucket",
      :public_url_base => "http://somebucket.s3-website-us-east-1.amazonaws.com/",
      :assets_url => "http://somebucket.s3-website-us-east-1.amazonaws.com/assets",
      :shared_secret => "XXXXXXXXXXXX", #used so build units can find each other, and for covereage postback
      :postback_url => "https://bot.example.org/coverage",
    }
    cov = SimpleCov::S3.new(cov_opts)
    cov.push_partial(:debug => true)
    cov.pull_merge_and_push_full
    cov2 = SimpleCov::S3.new(cov_opts.merge(:job_id => "457", :build_unit => "6"))
    cov2.push_partial(:debug => true)
    cov2.pull_merge_and_push_full
    #TODO: assert on the resulting contents of S3?
  end

end