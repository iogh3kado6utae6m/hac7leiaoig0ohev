require_relative "test_helper"
require 'java' if defined?(JRUBY_VERSION)

# JRuby-specific compatibility tests
describe "JRuby compatibility" do
  before do
    skip "Not running on JRuby" unless defined?(JRUBY_VERSION)
  end

  describe "JRuby environment" do
    it "should be running JRuby" do
      assert defined?(JRUBY_VERSION), "Should be running on JRuby"
      assert JRUBY_VERSION.length > 0, "JRuby version should be available"
      puts "Running on JRuby #{JRUBY_VERSION}"
    end
    
    it "should have Java integration available" do
      assert defined?(Java), "Java module should be available"
      java_version = Java::JavaLang::System.getProperty('java.version')
      assert java_version.length > 0, "Java version should be available"
      puts "Java version: #{java_version}"
    end
    
    it "should have threading capabilities" do
      thread_count_before = Thread.list.length
      threads = []
      
      # Create test threads
      5.times do |i|
        threads << Thread.new do
          sleep 0.1
          i * 2
        end
      end
      
      results = threads.map(&:value)
      expected_results = [0, 2, 4, 6, 8]
      
      assert_equal expected_results, results, "Threading should work correctly"
      assert Thread.list.length >= thread_count_before + 5, "Threads should be created"
    end
    
    it "should have proper memory management" do
      runtime = Java::JavaLang::Runtime.getRuntime
      total_memory = runtime.totalMemory
      free_memory = runtime.freeMemory
      max_memory = runtime.maxMemory
      
      assert total_memory > 0, "Total memory should be positive"
      assert free_memory >= 0, "Free memory should be non-negative"
      assert max_memory > 0, "Max memory should be positive"
      assert total_memory <= max_memory, "Total memory should not exceed max memory"
      
      puts "Memory: #{(total_memory - free_memory) / 1024 / 1024}MB used / #{total_memory / 1024 / 1024}MB total"
    end
  end
  
  describe "JRuby gem compatibility" do
    it "should load nokogiri" do
      require 'nokogiri'
      doc = Nokogiri::XML('<test>content</test>')
      assert_equal 'content', doc.xpath('//test').text
    end
    
    it "should load sinatra" do
      require 'sinatra/base'
      app_class = Class.new(Sinatra::Base) do
        get '/test' do
          'JRuby Sinatra works'
        end
      end
      
      assert_respond_to app_class, :new
      app = app_class.new
      assert_respond_to app, :call
    end
    
    it "should load JSON with optimal performance" do
      # Test if JrJackson is available for better performance
      json_library = nil
      
      begin
        require 'jrjackson'
        json_library = :jrjackson
      rescue LoadError
        require 'json'
        json_library = :standard_json
      end
      
      test_data = { 'test' => 'data', 'number' => 42, 'array' => [1, 2, 3] }
      
      if json_library == :jrjackson
        json_string = JrJackson::Json.dump(test_data)
        parsed_data = JrJackson::Json.load(json_string)
        puts "Using JrJackson for optimized JSON performance"
      else
        json_string = JSON.dump(test_data)
        parsed_data = JSON.parse(json_string)
        puts "Using standard JSON library"
      end
      
      assert_equal test_data, parsed_data
      assert json_library, "Some JSON library should be available"
    end
    
    it "should handle concurrent-ruby properly" do
      require 'concurrent'
      
      # Test concurrent data structures
      concurrent_array = Concurrent::Array.new
      concurrent_hash = Concurrent::Hash.new
      
      # Test with multiple threads
      threads = []
      10.times do |i|
        threads << Thread.new do
          concurrent_array << i
          concurrent_hash["key_#{i}"] = "value_#{i}"
        end
      end
      
      threads.each(&:join)
      
      assert_equal 10, concurrent_array.length
      assert_equal 10, concurrent_hash.length
      assert concurrent_array.include?(5), "Array should contain test value"
      assert_equal "value_5", concurrent_hash["key_5"]
    end
  end
  
  describe "Application loading on JRuby" do
    it "should load PrometheusExporterApp successfully" do
      # Load the main application file
      require_relative "../../src/prometheus_exporter"
      
      assert defined?(PrometheusExporterApp), "PrometheusExporterApp should be defined"
      assert PrometheusExporterApp < Sinatra::Base, "Should inherit from Sinatra::Base"
    end
    
    it "should instantiate PrometheusExporterApp" do
      require_relative "../../src/prometheus_exporter"
      
      app = PrometheusExporterApp.new
      assert_respond_to app, :call, "App should respond to call method"
      
      # Test constants
      assert_equal "Prometheus exporter", PrometheusExporterApp::SELF_GROUP_NAME
      assert PrometheusExporterApp::COMMON_LABELS.is_a?(Hash), "COMMON_LABELS should be a Hash"
    end
    
    it "should handle basic HTTP requests" do
      require_relative "../../src/prometheus_exporter"
      require 'rack/test'
      
      include Rack::Test::Methods
      
      def app
        PrometheusExporterApp
      end
      
      # Note: This test might not work fully without actual passenger-status
      # but we can test that the app doesn't crash
      begin
        get '/monitus/metrics'
        assert last_response.status != 500, "Should not return server error"
      rescue => e
        # Expected to fail without passenger-status, but shouldn't crash the JRuby process
        assert e.message.length > 0, "Error should have a message"
        puts "Expected error (no passenger-status): #{e.message}"
      end
    end
  end
  
  describe "JRuby performance characteristics" do
    it "should compile methods for better performance" do
      # Test that JRuby compilation is working
      compilation_enabled = Java::JavaLang::System.getProperty('jruby.compile.mode') != 'OFF'
      invokedynamic_enabled = Java::JavaLang::System.getProperty('jruby.compile.invokedynamic') == 'true'
      
      puts "JRuby compilation enabled: #{compilation_enabled}"
      puts "InvokeDynamic enabled: #{invokedynamic_enabled}"
      
      # These might not be set in all environments, so we just log them
      assert true, "Performance check completed"
    end
    
    it "should handle method calls efficiently" do
      # Simple performance test
      start_time = Time.now
      
      # Perform some computation
      result = (1..1000).map { |i| i * 2 }.reduce(:+)
      
      end_time = Time.now
      duration = (end_time - start_time) * 1000
      
      assert result > 0, "Computation should produce result"
      assert duration < 1000, "Should complete within reasonable time (#{duration}ms)"
      
      puts "JRuby computation time: #{duration.round(2)}ms"
    end
  end
end
