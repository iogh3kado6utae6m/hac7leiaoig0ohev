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
    
    # Should have HELP and TYPE lines
    assert_includes(response, "# HELP passenger_process_count")
    assert_includes(response, "# TYPE passenger_process_count gauge")
    
    # Should have metrics with labels
    assert_match(/passenger_process_count\{instance="[^"]+"\}/, response)
    assert_match(/passenger_supergroup_capacity_used\{instance="[^"]+",supergroup="[^"]+"\}/, response)
  end

  it "should not include prometheus exporter in metrics" do
    response = Net::HTTP.get(URI("http://passenger_with_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Should not contain metrics for the Prometheus exporter itself
    refute_includes(response, 'supergroup="Prometheus exporter"')
  end

  it "should handle errors gracefully" do
    # This test might not work in all environments, but checks error handling
    response = Net::HTTP.get(URI("http://passenger_without_app:10254/monitus/passenger-status-native_prometheus"))
    
    # Should either return metrics or a proper error message
    assert(response.include?("passenger_") || response.include?("Error:"))
  end
end
