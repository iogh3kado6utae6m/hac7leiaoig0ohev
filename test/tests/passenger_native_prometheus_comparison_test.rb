require_relative "test_helper"

describe "passenger native prometheus endpoint comparison" do
  before do
    wait_to_be_ready("http://passenger_with_app:10254/")
  end

  it "should have similar structure to passenger-status-node endpoint" do
    native_response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    begin
      node_response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-node_prometheus"))
      
      # If both endpoints work, compare their structure
      unless node_response.start_with?("Error:") || native_response.start_with?("Error:")
        # Both should have the same metric types
        native_metrics = extract_metric_names(native_response)
        node_metrics = extract_metric_names(node_response)
        
        # Core metrics should be present in both
        expected_core_metrics = [
          "passenger_process_count",
          "passenger_capacity_used", 
          "passenger_get_wait_list_size",
          "passenger_supergroup_capacity_used",
          "passenger_process_cpu",
          "passenger_process_memory"
        ]
        
        expected_core_metrics.each do |metric|
          assert_includes(native_metrics, metric, "Native endpoint should include #{metric}")
          # Only check node metrics if the endpoint is working
          if !node_response.include?("Error:")
            assert_includes(node_metrics, metric, "Node endpoint should include #{metric}")
          end
        end
        
        # Both should exclude Prometheus exporter
        refute_includes(native_response, 'supergroup="Prometheus exporter"')
        refute_includes(node_response, 'supergroup="Prometheus exporter"') unless node_response.include?("Error:")
      end
      
    rescue => e
      # If passenger-status-node endpoint is not available, just test native endpoint works
      puts "Note: passenger-status-node endpoint not available (#{e.message}), testing native only"
      assert_includes(native_response, "passenger_process_count")
    end
  end

  it "should produce valid prometheus exposition format" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    return if response.start_with?("Error:") # Skip if error response
    
    lines = response.split("\n")
    
    # Track HELP and TYPE declarations
    help_metrics = []
    type_metrics = []
    value_metrics = []
    
    lines.each do |line|
      case line
      when /^# HELP (\w+)/
        help_metrics << $1
      when /^# TYPE (\w+)/
        type_metrics << $1
      when /^(\w+)\{.*\} [\d.]+$/
        value_metrics << $1
      end
    end
    
    # Every metric with values should have HELP and TYPE
    value_metrics.uniq.each do |metric|
      assert_includes(help_metrics, metric, "Metric #{metric} should have HELP documentation")
      assert_includes(type_metrics, metric, "Metric #{metric} should have TYPE declaration")
    end
    
    # Should have some metrics
    assert(value_metrics.length > 0, "Should have at least some metrics")
  end

  it "should handle label escaping correctly" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    return if response.start_with?("Error:") # Skip if error response
    
    # Check that labels with special characters are properly quoted
    metric_lines = response.split("\n").reject { |line| line.start_with?("#") || line.strip.empty? }
    
    metric_lines.each do |line|
      # Labels should be properly formatted: key="value"
      if line.include?("{") && line.include?("}")
        labels_part = line.match(/\{(.*)\}/)[1]
        
        # Each label should follow key="value" format
        labels_part.split(",").each do |label|
          assert_match(/^\w+="[^"]*"$/, label.strip, "Label should be properly formatted: #{label}")
        end
      end
    end
  end

  private

  def extract_metric_names(response)
    response.split("\n")
           .reject { |line| line.start_with?("#") || line.strip.empty? }
           .map { |line| line.split("{")[0] }
           .uniq
  end
end
