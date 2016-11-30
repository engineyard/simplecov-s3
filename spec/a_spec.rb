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
    knapsack_rspec_report_path = File.expand_path("knapsack_rspec_report.json")
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
      :additional_artifacts_to_merge => [{
        key: "knapsack",
        file: knapsack_rspec_report_path,
        merge_with: Proc.new{|a,b| JSON.pretty_generate(JSON.parse(a).merge(JSON.parse(b))) }
      }]
    }
    File.open(knapsack_rspec_report_path, "w"){|fp| fp.write({foo: "bar"}.to_json)}
    cov = SimpleCov::S3.new(cov_opts)
    cov.push_partial(:debug => true)
    cov.pull_merge_and_push_full
    File.open(knapsack_rspec_report_path, "w"){|fp| fp.write({bar: "baz"}.to_json)}
    cov2 = SimpleCov::S3.new(cov_opts.merge(:job_id => "457", :build_unit => "6"))
    cov2.push_partial(:debug => true)
    cov2.pull_merge_and_push_full
    cov2.push_full
    expect(JSON.parse(File.read(knapsack_rspec_report_path))).to eq('foo' => 'bar', 'bar' => 'baz')
    #TODO: assert on the resulting contents of S3?
  end

end