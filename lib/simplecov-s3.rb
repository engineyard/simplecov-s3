require 'digest'
require 'securerandom'
require 'excon'
require 'fog'
require 'simplecov'
require 'json'

module SimpleCov
  class S3

    def self.ensured(task_to_invoke, &block)
      Rake::Task[task_to_invoke].invoke
    ensure
      begin
        yield
      rescue => e
        puts e.inspect
        puts e.backtrace
      end
    end

    class Formatter < SimpleCov::Formatter::HTMLFormatter
      #an ugly partial-copy from: https://github.com/colszowka/simplecov-html/blob/master/lib/simplecov-html.rb
      def format(result)
        template('layout').result(binding)
      end
    end

    def initialize(opts)
      @connection = Fog::Storage.new(opts[:fog])
      @public_url_base = opts[:public_url_base]
      @shared_secret = opts[:shared_secret]
      @assets_url = opts[:assets_url]
      @bucket_name = opts[:bucket_name]
      @build_units = opts[:build_units]
      @postback_url = opts[:postback_url]
      @build_unit = opts[:build_unit]
      @build_id = opts[:build_id]
      @job_id = opts[:job_id]
      @project_name = opts[:project_name] || "unknown"
      if @project_name.empty?
        @project_name = "unknown"
      end
      @history_limit = opts[:history_limit] || 15
    end

    def push_partial(opts = {})
      begin
        result = SimpleCov::ResultMerger.merged_result
        data_to_push = result.original_result.merge("BUILD_UNIT" => @build_unit).to_json
        put_file("#{@project_name}-#{commit_time}-coverageJSON/#{hashed_build_id}/#{@job_id}", data_to_push)
      rescue => e
        puts e.inspect
        puts e.backtrace
        puts "SOMEHTING WENT WRONG, PUSHING EMPTY COVERAGE FILE"
        put_file("#{@project_name}-#{commit_time}-coverageJSON/#{hashed_build_id}/#{@job_id}", {}.to_json)
      end
      if opts[:debug]
        debug_folder = "#{@project_name}-#{Time.now.to_i}-coverageDEBUG/#{hashed_build_id}-#{@job_id}"
        push_coverage_to(debug_folder, gen_body(result))
      end
    end

    def pull_merge_and_push_full
      if(json_files.size < @build_units)
        puts "Expected to see #{@build_units} files"
        puts "currently only #{json_files.size}"
        require 'pp'
        pp json_files.map(&:key)
        puts "Assuming some other build unit will be the last to exit, and merge/post full coverage"
        return false
      end
      puts "Coverage combined from #{json_files.size} units"
      results = []
      included_units = []
      json_files.each do |f|
        parsed = JSON.parse(f.body)
        included_units << parsed.delete("BUILD_UNIT")
        results << SimpleCov::Result.new(parsed)
      end
      puts "Included units: #{included_units.sort_by(&:to_s).inspect}"
      merged = {}
      results.each do |result|
        merged = result.original_result.merge_resultset(merged)
      end
      result = SimpleCov::Result.new(merged)
      push_coverage_to("#{@project_name}-#{Time.now.to_i}-coverageRESULT/#{SecureRandom.urlsafe_base64(33)}", gen_body(result), result.covered_percent, @postback_url)
      cleanup_files
    end

    def push_full
      result = SimpleCov::ResultMerger.merged_result
      push_coverage_to("#{@project_name}-#{Time.now.to_i}-coverageRESULT/#{SecureRandom.urlsafe_base64(33)}", gen_body(result), result.covered_percent, @postback_url)
      cleanup_files
    end

    private

    def cleanup_files
      json_files.each(&:destroy)
      all_files = @connection.directories.get(@bucket_name, :prefix => @project_name).files
      if all_files.size > @history_limit
        all_files.sort_by(&:last_modified)[0,all_files.size - @history_limit].each do |f|
          puts "Cleaning up #{f.key}"
          f.destroy
        end
      end
    end

    def put_file(path, data)
      puts "Putting to #{path} data size #{data.size}"
      @connection.directories.get(@bucket_name).files.create(:key => path, :body => data, :content_type => "text/html")
    end

    def json_files
      expected_dir = "#{@project_name}-#{commit_time}-coverageJSON/#{hashed_build_id}/"
      @connection.directories.get(@bucket_name, :prefix => expected_dir).files
    end

    def gen_body(result)
      Formatter.new.format(result).gsub("./assets",@assets_url)
    end

    def push_coverage_to(folder, data, covered_percent = nil, postback_url = false)
      coverage_url = "#{@public_url_base}#{folder}"
      puts "Pushing full coverage to #{coverage_url}"
      put_file("#{folder}/index.html", data)
      if postback_url
        puts "Postback coverage_url to #{postback_url}"
        coverage_percentage = "#{covered_percent.round(2)}"
        travis_id = @build_id
        signature = Digest::SHA1.hexdigest([coverage_url, coverage_percentage, travis_id, @shared_secret].join("."))
        post_params = {
            'coverage_url' => coverage_url,
            'coverage_percentage' => coverage_percentage,
            'travis_id' => travis_id,
            'signature' => signature,
        }
        puts "post params: " + post_params.inspect
        result = Excon.post(postback_url,
          :body => URI.encode_www_form(post_params),
          :headers => { "Content-Type" => "application/x-www-form-urlencoded" })
        puts result.inspect
      end
    end

    def commit_time
      @commit_time ||= DateTime.parse(`git show | grep Date`.gsub("Date:","").strip).strftime("%s")
    end

    def hashed_build_id
      @hashed_build_id ||= begin
        Digest::SHA1.hexdigest(@build_id + @shared_secret)
      end
    end

  end
end
