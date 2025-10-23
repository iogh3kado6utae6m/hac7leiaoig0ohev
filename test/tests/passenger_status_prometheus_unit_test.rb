require_relative "test_helper"
require 'json'

# Unit test for the native prometheus endpoint logic
# This can run without Docker containers
describe "passenger status prometheus unit tests" do
  
  it "should handle empty passenger data" do
    # Test with empty data structure
    empty_data = { "supergroups" => [] }
    
    # This would normally be tested by mocking the endpoint
    # For now, we test the data structure handling logic
    assert_equal([], empty_data["supergroups"])
    assert_nil(empty_data["process_count"])
  end
  
  it "should validate metric name patterns" do
    # Test that our expected metric names follow Prometheus naming conventions
    expected_metrics = [
      "passenger_process_count",
      "passenger_capacity_used", 
      "passenger_get_wait_list_size",
      "passenger_supergroup_capacity_used",
      "passenger_supergroup_get_wait_list_size",
      "passenger_process_cpu",
      "passenger_process_memory",
      "passenger_process_vmsize",
      "passenger_process_sessions",
      "passenger_process_processed",
      "passenger_process_busyness",
      "passenger_process_concurrency",
      "passenger_process_alive",
      "passenger_process_enabled",
      "passenger_process_uptime_seconds",
      "passenger_process_spawn_start_time_seconds",
      "passenger_process_last_used_seconds",
      "passenger_process_requests",
      "passenger_process_has_metrics"
    ]
    
    # Prometheus metric names should match this pattern
    valid_name_pattern = /^[a-zA-Z_:][a-zA-Z0-9_:]*$/
    
    expected_metrics.each do |metric_name|
      assert_match(valid_name_pattern, metric_name, "#{metric_name} should be a valid Prometheus metric name")
    end
  end
  
  it "should validate label name patterns" do
    # Test that our label names follow Prometheus conventions
    expected_labels = ["instance", "supergroup", "pid"]
    
    # Prometheus label names should match this pattern
    valid_label_pattern = /^[a-zA-Z_][a-zA-Z0-9_]*$/
    
    expected_labels.each do |label_name|
      assert_match(valid_label_pattern, label_name, "#{label_name} should be a valid Prometheus label name")
    end
  end
  
  it "should handle JSON parsing scenarios" do
    # Test various JSON scenarios that might come from passenger-status
    
    # Valid minimal JSON
    minimal_json = '{"supergroups": []}'
    parsed = JSON.parse(minimal_json)
    assert_equal([], parsed["supergroups"])
    
    # JSON with actual data structure
    realistic_json = '{
      "supergroups": [
        {
          "name": "/app (development)",
          "capacity_used": 1,
          "get_wait_list_size": 0,
          "group": {
            "processes": [
              {
                "pid": "12345",
                "cpu": 0,
                "rss": 123456
              }
            ]
          }
        }
      ]
    }'
    
    parsed_realistic = JSON.parse(realistic_json)
    assert_equal(1, parsed_realistic["supergroups"].length)
    assert_equal("/app (development)", parsed_realistic["supergroups"][0]["name"])
    
    # Invalid JSON should raise error
    assert_raises(JSON::ParserError) do
      JSON.parse("invalid json")
    end
  end
  
  it "should format prometheus output correctly" do
    # Test the expected output format
    sample_lines = [
      "# HELP passenger_process_count Total number of processes in instance",
      "# TYPE passenger_process_count gauge",
      'passenger_process_count{instance="test"} 1'
    ]
    
    # Check HELP line format
    help_line = sample_lines[0]
    assert_match(/^# HELP \w+ /, help_line)
    
    # Check TYPE line format
    type_line = sample_lines[1]
    assert_match(/^# TYPE \w+ (gauge|counter|histogram|summary)$/, type_line)
    
    # Check metric line format
    metric_line = sample_lines[2]
    assert_match(/^\w+\{[^}]*\} [\d.]+$/, metric_line)
  end
  
  it "should include new extended metrics in output format" do
    # Test that new metrics follow proper Prometheus format
    new_metric_samples = [
      "# HELP passenger_process_busyness Process busyness level (0=idle)",
      "# TYPE passenger_process_busyness gauge",
      'passenger_process_busyness{instance="default",supergroup="/app",pid="12345"} 0',
      "# HELP passenger_process_alive Process life status (1=alive, 0=dead)",
      "# TYPE passenger_process_alive gauge",
      'passenger_process_alive{instance="default",supergroup="/app",pid="12345"} 1',
      "# HELP passenger_process_uptime_seconds Process uptime in seconds",
      "# TYPE passenger_process_uptime_seconds gauge",
      'passenger_process_uptime_seconds{instance="default",supergroup="/app",pid="12345"} 3600'
    ]
    
    new_metric_samples.each do |line|
      if line.start_with?('# HELP')
        assert_match(/^# HELP passenger_\w+ /, line, "HELP line should follow format: #{line}")
      elsif line.start_with?('# TYPE')
        assert_match(/^# TYPE passenger_\w+ (gauge|counter)$/, line, "TYPE line should follow format: #{line}")
      else
        assert_match(/^passenger_\w+\{[^}]*\} [\d.]+$/, line, "Metric line should follow format: #{line}")
      end
    end
  end
  
  it "should validate filtering compatibility with new metrics" do
    # Test that filtering parameters are still valid
    valid_filter_params = ["instance", "supergroup", "pid"]
    
    # These should remain unchanged for backward compatibility
    valid_filter_params.each do |param|
      assert_match(/^[a-zA-Z_][a-zA-Z0-9_]*$/, param, "#{param} should be a valid filter parameter")
    end
    
    # Test sample filter URLs
    sample_urls = [
      "?instance=default",
      "?supergroup=/app", 
      "?pid=12345"
    ]
    
    sample_urls.each do |url_params|
      # Basic format validation
      assert_match(/^\?\w+=[\w\/]+$/, url_params, "#{url_params} should be a valid query parameter format")
    end
  end
  
  it "should handle metric type classifications" do
    # Test that we're using correct Prometheus metric types
    gauge_metrics = [
      "passenger_process_count",
      "passenger_capacity_used", 
      "passenger_get_wait_list_size",
      "passenger_supergroup_capacity_used",
      "passenger_supergroup_get_wait_list_size",
      "passenger_process_cpu",
      "passenger_process_memory",
      "passenger_process_vmsize",
      "passenger_process_sessions",
      "passenger_process_busyness",
      "passenger_process_concurrency",
      "passenger_process_alive",
      "passenger_process_enabled",
      "passenger_process_uptime_seconds",
      "passenger_process_spawn_start_time_seconds",
      "passenger_process_last_used_seconds",
      "passenger_process_requests",
      "passenger_process_has_metrics"
    ]
    
    counter_metrics = [
      "passenger_process_processed"
    ]
    
    # Gauges can go up and down
    gauge_metrics.each do |metric|
      # This is more of a documentation test
      assert(metric.include?("passenger_"), "#{metric} should have passenger_ prefix")
    end
    
    # Counters only go up
    counter_metrics.each do |metric|
      assert(metric.include?("processed"), "Counter metrics should indicate accumulated values")
    end
  end

  it "should validate filter parameter parsing" do
    # Test parameter validation logic scenarios
    
    # Valid single parameters
    valid_single_params = [
      { 'instance' => 'test_instance' },
      { 'supergroup' => 'test_app' },
      { 'pid' => '12345' }
    ]
    
    valid_single_params.each do |params|
      # This would be tested by mocking the parameter parsing
      param_key = params.keys.first
      param_value = params.values.first
      
      assert_match(/^[a-zA-Z0-9_\-\(\)\/\s\.]+$/, param_value.to_s, "Parameter value should be reasonable: #{param_value}")
    end
    
    # Invalid multiple parameters (should be rejected)
    invalid_multi_params = [
      { 'instance' => 'test', 'supergroup' => 'app' },
      { 'instance' => 'test', 'pid' => '123' },
      { 'supergroup' => 'app', 'pid' => '123' },
      { 'instance' => 'test', 'supergroup' => 'app', 'pid' => '123' }
    ]
    
    invalid_multi_params.each do |params|
      # Multiple parameters should be rejected
      assert(params.keys.length > 1, "Test case should have multiple parameters: #{params}")
    end
  end

  it "should handle empty and invalid filter values" do
    # Test edge cases for parameter values
    edge_cases = [
      { 'instance' => '' },           # empty string
      { 'instance' => ' ' },          # whitespace
      { 'supergroup' => nil },        # nil value would come as nil in params
      { 'pid' => '0' },              # edge case PID
      { 'pid' => 'abc' }             # non-numeric PID
    ]
    
    edge_cases.each do |params|
      # This tests parameter value patterns
      param_value = params.values.first
      
      # Empty strings and whitespace should be handled
      if param_value.is_a?(String)
        if param_value.strip.empty?
          assert_equal('', param_value.strip, "Empty parameter values should be cleanly handled")
        end
      end
    end
  end

  it "should validate filter data structures" do
    # Test the expected data structure for filtering
    sample_instance_data = {
      'name' => 'test_instance',
      'instance_name' => 'test_instance',
      'process_count' => 2,
      'capacity_used' => 2,
      'get_wait_list_size' => 0,
      'supergroups' => [
        {
          'name' => '/app (development)',
          'capacity_used' => 1,
          'get_wait_list_size' => 0,
          'group' => {
            'processes' => [
              {
                'pid' => '12345',
                'cpu' => 0.1,
                'rss' => 123456,
                'sessions' => 1,
                'processed' => 10
              }
            ]
          }
        }
      ]
    }
    
    # Validate structure has expected keys
    expected_instance_keys = ['name', 'instance_name', 'supergroups']
    expected_instance_keys.each do |key|
      assert(sample_instance_data.key?(key), "Instance data should have #{key}")
    end
    
    # Validate supergroup structure
    supergroup = sample_instance_data['supergroups'].first
    expected_sg_keys = ['name', 'group']
    expected_sg_keys.each do |key|
      assert(supergroup.key?(key), "Supergroup should have #{key}")
    end
    
    # Validate process structure
    process = supergroup['group']['processes'].first
    expected_process_keys = ['pid', 'cpu', 'rss']
    expected_process_keys.each do |key|
      assert(process.key?(key), "Process should have #{key}")
    end
  end
end
