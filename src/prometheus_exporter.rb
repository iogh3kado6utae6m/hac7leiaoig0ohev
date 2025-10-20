require 'nokogiri'
require 'sinatra/base'
require 'json'

# PrometheusExporterApp is a small Sinatra application that exports Passenger
# metrics in a Prometheus format
class PrometheusExporterApp < Sinatra::Base

  # Path to the monitor application
  SELF_GROUP_NAME = "Prometheus exporter"

  # Labels to add on each metric
  COMMON_LABELS = {"hostname" => ENV["HOSTNAME"]}

  get '/monitus/metrics' do # Endpoint return the metrics in a Prometheus format
    content_type :text
    return passenger_prometheus_metrics
  end

  get '/monitus/passenger-status-node_json' do

    content_type :json

    passenger_data = `"/home/$USER/.asdf/shims/passenger-status-node"`

    return {:error => 'Empty result'}.to_json if passenger_data.empty?

    return passenger_data
  end

  get '/monitus/passenger-status-node_prometheus' do

    content_type :text

    passenger_data = `"/home/$USER/.asdf/shims/passenger-status-node"`

    return 'Error: Empty result' if passenger_data.empty?

    passenger_data = JSON.parse(passenger_data)

    metrics = []

    passenger_data.each do |instance|
      instance_name = instance['name'] || 'unknown'

      # Метрики уровня инстанса
      metrics << "# HELP passenger_process_count Total number of processes in instance"
      metrics << "# TYPE passenger_process_count gauge"
      metrics << "passenger_process_count{instance=\"#{instance_name}\"} #{instance['process_count'] || 0}"

      metrics << "# HELP passenger_capacity_used Capacity used by instance"
      metrics << "# TYPE passenger_capacity_used gauge"
      metrics << "passenger_capacity_used{instance=\"#{instance_name}\"} #{instance['capacity_used'] || 0}"

      metrics << "# HELP passenger_get_wait_list_size Size of get wait list in instance"
      metrics << "# TYPE passenger_get_wait_list_size gauge"
      metrics << "passenger_get_wait_list_size{instance=\"#{instance_name}\"} #{instance['get_wait_list_size'] || 0}"

      # Метрики для supergroups
      (instance['supergroups'] || []).each do |supergroup|
        supergroup_name = supergroup['name'] || 'unknown'

        metrics << "# HELP passenger_supergroup_capacity_used Capacity used by supergroup"
        metrics << "# TYPE passenger_supergroup_capacity_used gauge"
        metrics << "passenger_supergroup_capacity_used{instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\"} #{supergroup['capacity_used'] || 0}"

        metrics << "# HELP passenger_supergroup_get_wait_list_size Size of get wait list in supergroup"
        metrics << "# TYPE passenger_supergroup_get_wait_list_size gauge"
        metrics << "passenger_supergroup_get_wait_list_size{instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\"} #{supergroup['get_wait_list_size'] || 0}"

        # Метрики для процессов
        (supergroup['group']['processes'] || []).each do |process|
          pid = process['pid'] || 'unknown'

          metrics << "# HELP passenger_process_cpu CPU usage by process"
          metrics << "# TYPE passenger_process_cpu gauge"
          metrics << "passenger_process_cpu{instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\",pid=\"#{pid}\"} #{process['cpu'] || 0}"

          metrics << "# HELP passenger_process_memory Memory usage by process (rss)"
          metrics << "# TYPE passenger_process_memory gauge"
          metrics << "passenger_process_memory{instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\",pid=\"#{pid}\"} #{process['rss'] || 0}"

          metrics << "# HELP passenger_process_sessions Active sessions by process"
          metrics << "# TYPE passenger_process_sessions gauge"
          metrics << "passenger_process_sessions{instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\",pid=\"#{pid}\"} #{process['session'] || 0}"

          metrics << "# HELP passenger_process_processed Total requests processed by process"
          metrics << "# TYPE passenger_process_processed counter"
          metrics << "passenger_process_processed{instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\",pid=\"#{pid}\"} #{process['processed'] || 0}"
        end
      end
    end

    return metrics.join("\n")
  end

  get '/monitus/passenger-status' do
    content_type :text
    result = `/usr/sbin/passenger-status --verbose`
    return result
  end

  get '/monitus/passenger-config_system-metrics' do
    content_type :text
    result = `/usr/bin/passenger-config system-metrics`
    return result
  end

  get '/monitus/passenger-config_system-properties' do
    content_type :json
    result = `/usr/bin/passenger-config system-properties`
    return result
  end

  get '/monitus/passenger-memory-stats' do
    content_type :text
    result = `/usr/sbin/passenger-memory-stats`
    return result
  end

  get '/monitus/passenger-config_api-call_get_pool' do
    content_type :json
    result = `/usr/bin/passenger-config api-call get /pool.json`
    return result
  end

  get '/monitus/passenger-config_api-call_get_server' do
    content_type :json
    result = `/usr/bin/passenger-config api-call get /server.json` # Need `sudo`
    return {:error => 'Unauthorized'}.to_json if result.include?('Unauthorized')
    return result
  end

  def passenger_prometheus_metrics # Return passenger-status metrics in a Prometheus format
    supergroups = passenger_status.xpath("info/supergroups/supergroup")
    return "# ERROR: No other application has been loaded yet" if supergroups.length == 1

    metrics = []
    for supergroup in hide_ourselves(supergroups) do
      for group in supergroup.xpath("group") do
        labels = {"supergroup_name" => supergroup.xpath("name").text, "group_name" => group.xpath("name").text}
        active_processes = group.xpath("processes/process/busyness").reject{|x| x.text == "0"}.length
        metrics.concat(prometheus_metric("passenger_processes_active", "Active processes", "gauge", labels, active_processes))
        metrics.concat(prometheus_metric("passenger_capacity", "Capacity used", "gauge", labels, group.xpath("capacity_used").text))
        metrics.concat(prometheus_metric("passenger_wait_list_size", "Requests in the queue", "gauge", labels, group.xpath("get_wait_list_size").text))
      end
    end

    return metrics.map{ |line| "#{line}\n"}
  end

  def prometheus_metric(name, help, type, labels, value) # Return lines describing one single Prometheus metric
    labels_str = labels.merge(COMMON_LABELS).map{|x,y| "#{x}=\"#{y}\""}.join(",")
    metric = []
    metric << "# HELP #{name} #{help}"
    metric << "# TYPE #{name} #{type}"
    metric << "#{name}{#{labels_str}} #{value}"
    metric
  end

  def hide_ourselves(supergroups) # Hide the Prometheus exporter from the output
    supergroups.reject{ |s| s.xpath("name").text ==  SELF_GROUP_NAME }
  end

  def passenger_status # Execute passenger-status and return the result as XML
    # The official Phusion image has a Ruby wrapper that prepend script outputs with
    # the path of the Ruby version being used

    # This breaks XML parsing, and that's why we explicitly execute Ruby to avoid
    # using the Shebang of passenger-status that has this broken wrapper
    raw_xml = `ruby \`which passenger-status\` -v --show=xml 2>/dev/null`
    Nokogiri::XML(raw_xml) { |config| config.strict }
  end
end
