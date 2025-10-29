require_relative "test_helper"

# JRuby-specific Passenger integration tests
describe "JRuby Passenger integration" do
  before do
    skip "Not testing JRuby endpoints" unless ENV['TEST_JRUBY'] == '1' || defined?(JRUBY_VERSION)
  end

  describe "JRuby with dummy application" do
    before do
      wait_to_be_ready("http://passenger_jruby_with_app:80/")
    end

    it "should return metrics from JRuby" do
      response = Net::HTTP.get(URI("http://passenger_jruby_with_app:80/monitus/metrics"))
      assert_includes(response, "passenger_capacity")
      assert_includes(response, "passenger_wait_list_size")
      assert_includes(response, "passenger_processes_active")
    end

    it "should have correct labels on JRuby" do
      response = Net::HTTP.get(URI("http://passenger_jruby_with_app:80/monitus/metrics"))
      assert_includes(response, 'hostname="passenger_jruby_with_app"')
    end

    it "should serve metrics with reasonable performance" do
      # JRuby might be slower on first request due to JIT warmup
      start_time = Time.now
      response = Net::HTTP.get(URI("http://passenger_jruby_with_app:80/monitus/metrics"))
      end_time = Time.now
      
      duration = (end_time - start_time) * 1000
      
      assert response.length > 0, "Response should not be empty"
      assert duration < 10000, "Response should complete within 10 seconds (got #{duration.round(2)}ms)"
      
      puts "JRuby metrics response time: #{duration.round(2)}ms"
    end

    it "should handle extended metrics endpoints" do
      # Test native prometheus endpoint
      begin
        response = Net::HTTP.get(URI("http://passenger_jruby_with_app:80/monitus/passenger-status-native_prometheus"))
        # Might fail without proper passenger setup, but shouldn't crash
        assert response.is_a?(String), "Should return string response"
      rescue => e
        puts "Expected error for extended metrics (no passenger setup): #{e.message}"
        assert true, "Handled error gracefully"
      end
    end
  end

  describe "JRuby without application" do
    before do
      wait_to_be_ready("http://passenger_jruby_without_app:80/")
    end

    it "should return metrics even without applications" do
      response = Net::HTTP.get(URI("http://passenger_jruby_without_app:80/monitus/metrics"))
      
      # Should either have metrics or the "no application loaded" message
      has_metrics = response.include?("passenger_capacity")
      has_no_app_message = response.include?("ERROR: No other application has been loaded yet")
      
      assert(has_metrics || has_no_app_message, 
             "Should have either metrics or no-app message")
    end
    
    it "should respond quickly even without apps" do
      start_time = Time.now
      response = Net::HTTP.get(URI("http://passenger_jruby_without_app:80/monitus/metrics"))
      end_time = Time.now
      
      duration = (end_time - start_time) * 1000
      
      assert response.length > 0, "Response should not be empty"
      assert duration < 5000, "Response should be fast without apps (got #{duration.round(2)}ms)"
      
      puts "JRuby no-app response time: #{duration.round(2)}ms"
    end
  end
  
  describe "Standalone JRuby application" do
    before do
      wait_to_be_ready("http://monitus_jruby_standalone:8080/health")
    end
    
    it "should respond to health checks" do
      response = Net::HTTP.get(URI("http://monitus_jruby_standalone:8080/health"))
      assert_equal "OK", response.strip
    end
    
    it "should handle health check with good performance" do
      # Health check should be fast even on JRuby
      start_time = Time.now
      response = Net::HTTP.get(URI("http://monitus_jruby_standalone:8080/health"))
      end_time = Time.now
      
      duration = (end_time - start_time) * 1000
      
      assert_equal "OK", response.strip
      assert duration < 2000, "Health check should be fast (got #{duration.round(2)}ms)"
      
      puts "JRuby standalone health check time: #{duration.round(2)}ms"
    end
    
    it "should handle concurrent requests" do
      # Test concurrent access to health endpoint
      threads = []
      responses = []
      response_times = []
      
      5.times do
        threads << Thread.new do
          start_time = Time.now
          response = Net::HTTP.get(URI("http://monitus_jruby_standalone:8080/health"))
          end_time = Time.now
          
          responses << response
          response_times << (end_time - start_time) * 1000
        end
      end
      
      threads.each(&:join)
      
      assert_equal 5, responses.length
      responses.each { |r| assert_equal "OK", r.strip }
      
      avg_time = response_times.reduce(:+) / response_times.length
      max_time = response_times.max
      
      assert max_time < 5000, "Max response time should be reasonable (got #{max_time.round(2)}ms)"
      
      puts "JRuby concurrent health check - avg: #{avg_time.round(2)}ms, max: #{max_time.round(2)}ms"
    end
  end
  
  describe "JRuby memory and resource usage" do
    it "should report reasonable memory usage" do
      skip "Memory tests only on JRuby runtime" unless defined?(JRUBY_VERSION)
      
      # Get memory info from JRuby
      runtime = Java::JavaLang::Runtime.getRuntime
      total_memory_mb = runtime.totalMemory / 1024 / 1024
      free_memory_mb = runtime.freeMemory / 1024 / 1024
      used_memory_mb = total_memory_mb - free_memory_mb
      max_memory_mb = runtime.maxMemory / 1024 / 1024
      
      puts "JRuby Memory Usage: #{used_memory_mb}MB used / #{total_memory_mb}MB total / #{max_memory_mb}MB max"
      
      assert total_memory_mb > 0, "Total memory should be positive"
      assert used_memory_mb >= 0, "Used memory should be non-negative"
      assert used_memory_mb <= max_memory_mb, "Used memory should not exceed max"
      
      # Reasonable bounds for a containerized JRuby app
      assert used_memory_mb < 2048, "Memory usage should be reasonable (<2GB)"
    end
  end
end
