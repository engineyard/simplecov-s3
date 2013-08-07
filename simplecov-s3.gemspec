# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "simplecov-s3/version"

Gem::Specification.new do |s|
  s.name        = "simplecov-s3"
  s.version     = SimpleCov::S3::VERSION
  s.authors     = ["Jacob"]
  s.email       = ["jacob@engineyard.com"]
  s.homepage    = "https://github.com/engineyard/simplecov-s3"
  s.summary     = %q{Merge simplecov outputs using S3 as shared storage (and publish the results as html to S3)}
  s.description = %q{Merge simplecov outputs using S3 as shared storage (and publish the results as html to S3) (works best with travis)}

  s.files         = (`git ls-files`.split("\n") - `git ls-files -- fake`.split("\n"))
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'rspec'
  s.add_dependency "fog"
  s.add_dependency 'simplecov'
end
