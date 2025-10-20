require_relative "test_helper"

describe "passenger native prometheus endpoint" do
  before do
    wait_to_be_ready("http://passenger_with_app:10254/")
  end

  it "should return prometheus metrics" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Should contain basic instance metrics
    assert_includes(response, "passenger_process_count")
    assert_includes(response, "passenger_capacity_used")
    assert_includes(response, "passenger_get_wait_list_size")
    
    # Should contain supergroup metrics
    assert_includes(response, "passenger_supergroup_capacity_used")
    assert_includes(response, "passenger_supergroup_get_wait_list_size")
    
    # Should contain process-level metrics
    assert_includes(response, "passenger_process_cpu")
    assert_includes(response, "passenger_process_memory")
    assert_includes(response, "passenger_process_sessions")
    assert_includes(response, "passenger_process_processed")
  end

  it "should have proper prometheus format" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Should have HELP and TYPE lines for each metric type
    assert_includes(response, "# HELP passenger_process_count Total number of processes in instance")
    assert_includes(response, "# TYPE passenger_process_count gauge")
    
    assert_includes(response, "# HELP passenger_capacity_used Capacity used by instance")
    assert_includes(response, "# TYPE passenger_capacity_used gauge")
    
    assert_includes(response, "# HELP passenger_process_cpu CPU usage by process")
    assert_includes(response, "# TYPE passenger_process_cpu gauge")
    
    assert_includes(response, "# HELP passenger_process_memory Memory usage by process (rss)")
    assert_includes(response, "# TYPE passenger_process_memory gauge")
    
    assert_includes(response, "# HELP passenger_process_processed Total requests processed by process")
    assert_includes(response, "# TYPE passenger_process_processed counter")
    
    # Should have metrics with proper label structure
    assert_match(/passenger_process_count\{instance="[^"]+"\} \d+/, response)
    assert_match(/passenger_supergroup_capacity_used\{instance="[^"]+",supergroup="[^"]+"\} \d+/, response)
    assert_match(/passenger_process_cpu\{instance="[^"]+",supergroup="[^"]+",pid="[^"]+"\} \d+/, response)
  end

  it "should not include prometheus exporter in metrics" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Should not contain metrics for the Prometheus exporter itself
    refute_includes(response, 'supergroup="Prometheus exporter"')
  end

  it "should return valid numeric values" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Extract metric values and verify they are numeric
    metric_lines = response.split("\n").reject { |line| line.start_with?("#") || line.strip.empty? }
    
    metric_lines.each do |line|
      # Each metric line should end with a numeric value
      assert_match(/\} \d+(\.\d+)?$/, line, "Metric line should end with numeric value: #{line}")
    end
    
    # Should have at least some metrics
    assert(metric_lines.length > 0, "Should have at least some metric lines")
  end

  it "should handle different supergroup names correctly" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Should handle supergroup names with special characters (like parentheses)
    # Example: /app (development)
    assert_match(/supergroup="[^"]*\([^"]*\)[^"]*"/, response)
  end

  it "should provide process-level details" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Should have process-level metrics with PID labels
    assert_match(/pid="\d+"/, response, "Should include process PID in metrics")
    
    # Should have all expected process metrics for at least one process
    if response.include?("passenger_process_cpu")
      # If we have CPU metrics, we should also have memory and other process metrics
      assert_includes(response, "passenger_process_memory")
      assert_includes(response, "passenger_process_sessions")
      assert_includes(response, "passenger_process_processed")
    end
  end

  it "should handle empty or error responses gracefully" do
    response = Net::HTTP.get(URI("http://passenger_without_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Should either return valid metrics or a proper error message
    assert(response.include?("passenger_") || response.start_with?("Error:"), 
           "Should return either metrics or error message, got: #{response[0..100]}")
    
    # If it's an error, should be descriptive
    if response.start_with?("Error:")
      assert(response.length > 10, "Error message should be descriptive")
    end
  end

  it "should return content-type text/plain" do
    uri = URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    
    assert_equal("200", response.code, "Should return HTTP 200")
    assert_match(/text/, response.content_type, "Should return text content type")
  end
end
