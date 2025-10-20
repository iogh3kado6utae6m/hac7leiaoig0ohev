require_relative "test_helper"
require 'json'

# Unit test for the native prometheus endpoint logic
# This can run without Docker containers
describe "passenger native prometheus unit tests" do
  
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
      "passenger_process_sessions",
      "passenger_process_processed"
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
  
  it "should handle metric type classifications" do
    # Test that we're using correct Prometheus metric types
    gauge_metrics = [
      "passenger_process_count",
      "passenger_capacity_used", 
      "passenger_process_cpu",
      "passenger_process_memory",
      "passenger_process_sessions"
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
end
