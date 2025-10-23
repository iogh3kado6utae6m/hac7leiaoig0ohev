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

  get '/monitus/passenger-status-native_prometheus' do
    # Native Ruby implementation that reproduces passenger-status-node logic
    # 1. Get instance names from passenger-status
    # 2. Get XML data for each instance 
    # 3. Parse and convert to same JSON structure as passenger-status-node
    content_type :text
    
    begin
      # Step 1: Get instance names (same logic as passenger-status-node getNames function)
      instances_data = get_passenger_instances
      
      if params['debug'] == '1'
        return "Instances data: #{instances_data.inspect}\n"
      end
      
      # Step 2: Convert to same format as passenger-status-node_prometheus
      metrics = generate_passenger_node_prometheus_metrics(instances_data)
      
      return metrics.join("\n")
      
    rescue => e
      return "Error: #{e.message}"
    end
  end

  get '/monitus/passenger-status-prometheus' do
    # Extended endpoint with filtering support
    # Query parameters:
    #   ?instance=name - show only specified instance
    #   ?supergroup=name - show only specified supergroup across all instances  
    #   ?pid=123 - show only specified process across all supergroups
    # Only one parameter allowed at a time
    content_type :text
    
    begin
      # Parse and validate filter parameters
      filter_params = parse_filter_parameters(params)
      
      # Get instance data
      instances_data = get_passenger_instances
      
      if params['debug'] == '1'
        return "Instances data: #{instances_data.inspect}\nFilter params: #{filter_params.inspect}\n"
      end
      
      # Apply filtering if parameters provided
      if filter_params.any?
        instances_data = filter_instances_data(instances_data, filter_params)
      end
      
      # Generate metrics from filtered data
      metrics = generate_passenger_node_prometheus_metrics(instances_data)
      
      return metrics.join("\n")
      
    rescue => e
      return "Error: #{e.message}"
    end
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

  get '/monitus/debug-passenger-status-json' do
    content_type :json
    passenger_json = `ruby \`which passenger-status\` -v --show=json 2>/dev/null`
    return passenger_json
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

  # Filter instances data based on query parameters
  def filter_instances_data(instances_data, filter_params)
    return instances_data if filter_params.empty?
    
    filtered_instances = []
    
    instances_data.each do |instance|
      filtered_instance = instance.dup
      
      # Apply instance filter
      if filter_params[:instance]
        next unless (instance['instance_name'] || instance['name']) == filter_params[:instance]
      end
      
      # Apply supergroup filter  
      if filter_params[:supergroup]
        filtered_supergroups = (instance['supergroups'] || []).select do |sg|
          sg['name'] == filter_params[:supergroup]
        end
        filtered_instance['supergroups'] = filtered_supergroups
        
        # Recalculate instance totals after supergroup filtering
        if filtered_supergroups.any?
          process_counts = filtered_supergroups.map { |sg| 
            processes = (sg['group'] || {})['processes']
            processes ? processes.length : 0
          }
          filtered_instance['process_count'] = ruby_sum(process_counts)
          
          capacities = filtered_supergroups.map { |sg| sg['capacity_used'] || 0 }
          filtered_instance['capacity_used'] = ruby_sum(capacities)
          
          wait_sizes = filtered_supergroups.map { |sg| sg['get_wait_list_size'] || 0 }
          filtered_instance['get_wait_list_size'] = ruby_sum(wait_sizes)
        else
          # No matching supergroups, skip this instance
          next
        end
      end
      
      # Apply PID filter
      if filter_params[:pid]
        filtered_supergroups = []
        (filtered_instance['supergroups'] || []).each do |sg|
          sg_copy = sg.dup
          group_copy = (sg['group'] || {}).dup
          
          filtered_processes = ((sg['group'] || {})['processes'] || []).select do |proc|
            proc['pid'].to_s == filter_params[:pid].to_s
          end
          
          if filtered_processes.any?
            group_copy['processes'] = filtered_processes
            sg_copy['group'] = group_copy
            
            # Recalculate supergroup metrics for filtered processes
            sg_copy['capacity_used'] = filtered_processes.length
            sg_copy['get_wait_list_size'] = 0 # Individual process doesn't have queue
            
            filtered_supergroups << sg_copy
          end
        end
        
        if filtered_supergroups.any?
          filtered_instance['supergroups'] = filtered_supergroups
          process_counts = filtered_supergroups.map { |sg| 
            (sg['group']['processes'] || []).length 
          }
          filtered_instance['process_count'] = ruby_sum(process_counts)
          filtered_instance['capacity_used'] = filtered_instance['process_count']
          filtered_instance['get_wait_list_size'] = 0
        else
          # No matching processes, skip this instance
          next
        end
      end
      
      filtered_instances << filtered_instance
    end
    
    filtered_instances
  end
  
  # Parse and validate query parameters for filtering
  def parse_filter_parameters(params)
    filter_params = {}
    param_count = 0
    
    if params['instance'] && !params['instance'].empty?
      filter_params[:instance] = params['instance']
      param_count += 1
    end
    
    if params['supergroup'] && !params['supergroup'].empty?
      filter_params[:supergroup] = params['supergroup']
      param_count += 1
    end
    
    if params['pid'] && !params['pid'].empty?
      filter_params[:pid] = params['pid']
      param_count += 1
    end
    
    # Only allow one filter parameter at a time
    if param_count > 1
      raise "Only one filter parameter allowed at a time. Provided: #{filter_params.keys.join(', ')}"
    end
    
    filter_params
  end

  private

  # Ruby version-aware sum method
  def ruby_sum(array)
    if RUBY_VERSION >= '2.4.0'
      # Use modern sum method for Ruby 2.4+
      array.sum
    else
      # Use traditional inject for Ruby 2.3.x
      array.inject(0, :+)
    end
  end

  # Convert passenger-status JSON format to passenger-status-node compatible format

  # Reproduce passenger-status-node logic
  def get_passenger_instances
    # Step 1: Get instance names (reproduce getNames function)
    instance_names = get_instance_names
    
    # Step 2: Get metrics for each instance (reproduce getInstanceMetrics)
    instances = []
    
    if instance_names.empty?
      # Single instance case - get data without instance name
      xml_data = `ruby \`which passenger-status\` --show=xml -v 2>/dev/null`
      unless xml_data.empty?
        instances << parse_passenger_xml(xml_data, 'default')
      end
    else
      # Multiple instances case
      instance_names.each do |name|
        xml_data = `ruby \`which passenger-status\` --show=xml -v #{name} 2>/dev/null`
        unless xml_data.empty?
          instances << parse_passenger_xml(xml_data, name)
        end
      end
    end
    
    instances.compact
  end
  
  # Reproduce getNames function from passenger-status-node
  def get_instance_names
    status_output = `ruby \`which passenger-status\` 2>/dev/null`
    return [] if status_output.empty?
    
    # Check if multiple instances (error condition in JS code)
    if status_output.include?('ERROR') || status_output.include?('Multiple')
      # Parse multiple instance names from output
      lines = status_output.split("\n")
      names = []
      lines.each do |line|
        if line.match(/^[a-zA-Z0-9_]+$/)
          names << line.strip
        end
      end
      return names
    else
      # Single instance case - extract instance name
      match = status_output.match(/Instance: *([a-zA-Z0-9_]*)/)
      return match ? [match[1]] : []
    end
  end
  
  # Parse XML and convert to JSON structure (reproduce parseXML + reformat)
  def parse_passenger_xml(xml_data, instance_name)
    doc = Nokogiri::XML(xml_data) { |config| config.strict }
    
    # Extract info section (like obj.info in JS)
    info = doc.xpath('//info').first
    return nil unless info
    
    result = {
      'name' => instance_name,
      'instance_name' => instance_name
    }
    
    # Add instance-level data
    %w[instance_id process_count capacity_used get_wait_list_size].each do |field|
      element = info.xpath(field).first
      result[field] = element ? element.text : nil
    end
    
    # Process supergroups (reproduce reformat function logic)
    supergroups = []
    info.xpath('supergroups/supergroup').each do |sg|
      supergroup_name = sg.xpath('name').text
      
      # Skip self (reproduce original behavior)
      next if supergroup_name == SELF_GROUP_NAME
      
      sg_data = {
        'name' => supergroup_name,
        'capacity_used' => sg.xpath('capacity_used').text.to_i,
        'get_wait_list_size' => sg.xpath('get_wait_list_size').text.to_i,
        'group' => {
          'processes' => []
        }
      }
      
      # Process individual processes
      sg.xpath('group/processes/process').each do |proc|
        process_data = {
          'pid' => proc.xpath('pid').text,
          'cpu' => proc.xpath('cpu').text.to_f,
          'rss' => proc.xpath('real_memory').text.to_i,
          'vmsize' => proc.xpath('vmsize').text.to_i,
          'sessions' => proc.xpath('sessions').text.to_i,
          'processed' => proc.xpath('processed').text.to_i,
          'busyness' => proc.xpath('busyness').text.to_i,
          'concurrency' => proc.xpath('concurrency').text.to_i,
          'life_status' => proc.xpath('life_status').text,
          'enabled' => proc.xpath('enabled').text == 'true',
          'uptime' => proc.xpath('uptime').text.to_i,
          'spawn_start_time' => proc.xpath('spawn_start_time').text.to_i,
          'last_used' => proc.xpath('last_used').text.to_i,
          'requests' => proc.xpath('requests').text.to_i,
          'has_metrics' => proc.xpath('has_metrics').text == 'true'
        }
        sg_data['group']['processes'] << process_data
      end
      
      supergroups << sg_data
    end
    
    result['supergroups'] = supergroups
    
    # Calculate totals if not present
    unless result['process_count']
      process_counts = supergroups.map { |sg| sg['group']['processes'].length }
      result['process_count'] = ruby_sum(process_counts)
    else
      result['process_count'] = result['process_count'].to_i
    end
    
    unless result['capacity_used']
      capacities = supergroups.map { |sg| sg['capacity_used'] }
      result['capacity_used'] = ruby_sum(capacities)
    else
      result['capacity_used'] = result['capacity_used'].to_i
    end
    
    unless result['get_wait_list_size']
      wait_lists = supergroups.map { |sg| sg['get_wait_list_size'] }
      result['get_wait_list_size'] = ruby_sum(wait_lists)
    else
      result['get_wait_list_size'] = result['get_wait_list_size'].to_i
    end
    
    result
  end


  def generate_passenger_node_prometheus_metrics(passenger_data)
    # Convert passenger-status JSON to same format as passenger-status-node_prometheus
    metrics = []
    
    # Handle single instance or array of instances
    instances = passenger_data.is_a?(Array) ? passenger_data : [passenger_data]
    
    instances.each do |instance|
      instance_name = instance['instance_name'] || instance['name'] || 'unknown'
      
      # Instance-level metrics
      supergroups = instance['supergroups'] || []
      
      # Calculate process count (version-dependent method)
      process_count = instance['process_count']
      if process_count.nil?
        process_counts = supergroups.map { |sg| 
          processes = (sg['group'] || {})['processes']
          processes ? processes.length : 0
        }
        process_count = ruby_sum(process_counts)
      end
      
      # Calculate capacity used (version-dependent method)
      capacity_used = instance['capacity_used']
      if capacity_used.nil?
        capacities = supergroups.map { |sg| sg['capacity_used'] || 0 }
        capacity_used = ruby_sum(capacities)
      end
      
      # Calculate wait list size (version-dependent method)
      wait_list_size = instance['get_wait_list_size']
      if wait_list_size.nil?
        wait_sizes = supergroups.map { |sg| sg['get_wait_list_size'] || 0 }
        wait_list_size = ruby_sum(wait_sizes)
      end
      
      metrics << "# HELP passenger_process_count Total number of processes in instance"
      metrics << "# TYPE passenger_process_count gauge"
      metrics << "passenger_process_count{instance=\"#{instance_name}\"} #{process_count}"
      
      metrics << "# HELP passenger_capacity_used Capacity used by instance"
      metrics << "# TYPE passenger_capacity_used gauge"
      metrics << "passenger_capacity_used{instance=\"#{instance_name}\"} #{capacity_used}"
      
      metrics << "# HELP passenger_get_wait_list_size Size of get wait list in instance"
      metrics << "# TYPE passenger_get_wait_list_size gauge"
      metrics << "passenger_get_wait_list_size{instance=\"#{instance_name}\"} #{wait_list_size}"
      
      # Process supergroups
      (instance['supergroups'] || []).each do |supergroup|
        supergroup_name = supergroup['name'] || 'unknown'
        
        # Skip self (Prometheus exporter)
        next if supergroup_name == SELF_GROUP_NAME
        
        metrics << "# HELP passenger_supergroup_capacity_used Capacity used by supergroup"
        metrics << "# TYPE passenger_supergroup_capacity_used gauge"
        metrics << "passenger_supergroup_capacity_used{instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\"} #{supergroup['capacity_used'] || 0}"
        
        metrics << "# HELP passenger_supergroup_get_wait_list_size Size of get wait list in supergroup"
        metrics << "# TYPE passenger_supergroup_get_wait_list_size gauge"
        metrics << "passenger_supergroup_get_wait_list_size{instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\"} #{supergroup['get_wait_list_size'] || 0}"
        
        # Process individual processes
        group = supergroup['group'] || {}
        (group['processes'] || []).each do |process|
          pid = process['pid'] || 'unknown'
          labels = "instance=\"#{instance_name}\",supergroup=\"#{supergroup_name}\",pid=\"#{pid}\""
          
          # CPU usage
          metrics << "# HELP passenger_process_cpu CPU usage by process"
          metrics << "# TYPE passenger_process_cpu gauge"
          metrics << "passenger_process_cpu{#{labels}} #{process['cpu'] || 0}"
          
          # Memory usage (RSS)
          metrics << "# HELP passenger_process_memory Memory usage by process (rss)"
          metrics << "# TYPE passenger_process_memory gauge"
          metrics << "passenger_process_memory{#{labels}} #{process['rss'] || process['real_memory'] || 0}"
          
          # Memory usage (Virtual Memory Size)
          metrics << "# HELP passenger_process_vmsize Virtual memory size by process"
          metrics << "# TYPE passenger_process_vmsize gauge"
          metrics << "passenger_process_vmsize{#{labels}} #{process['vmsize'] || 0}"
          
          # Active sessions
          metrics << "# HELP passenger_process_sessions Active sessions by process"
          metrics << "# TYPE passenger_process_sessions gauge"
          metrics << "passenger_process_sessions{#{labels}} #{process['sessions'] || process['session'] || 0}"
          
          # Total requests processed
          metrics << "# HELP passenger_process_processed Total requests processed by process"
          metrics << "# TYPE passenger_process_processed counter"
          metrics << "passenger_process_processed{#{labels}} #{process['processed'] || process['requests_processed'] || 0}"
          
          # Process busyness (0 = idle, >0 = busy)
          metrics << "# HELP passenger_process_busyness Process busyness level (0=idle)"
          metrics << "# TYPE passenger_process_busyness gauge"
          metrics << "passenger_process_busyness{#{labels}} #{process['busyness'] || 0}"
          
          # Concurrency level
          metrics << "# HELP passenger_process_concurrency Number of concurrent requests being processed"
          metrics << "# TYPE passenger_process_concurrency gauge"
          metrics << "passenger_process_concurrency{#{labels}} #{process['concurrency'] || 0}"
          
          # Process life status (1 = alive, 0 = dead)
          life_status_value = (process['life_status'] == 'ALIVE' || process['life_status'] == 'alive') ? 1 : 0
          metrics << "# HELP passenger_process_alive Process life status (1=alive, 0=dead)"
          metrics << "# TYPE passenger_process_alive gauge"
          metrics << "passenger_process_alive{#{labels}} #{life_status_value}"
          
          # Process enabled status (1 = enabled, 0 = disabled)
          enabled_value = (process['enabled'] == true || process['enabled'] == 'true') ? 1 : 0
          metrics << "# HELP passenger_process_enabled Process enabled status (1=enabled, 0=disabled)"
          metrics << "# TYPE passenger_process_enabled gauge"
          metrics << "passenger_process_enabled{#{labels}} #{enabled_value}"
          
          # Process uptime in seconds
          metrics << "# HELP passenger_process_uptime_seconds Process uptime in seconds"
          metrics << "# TYPE passenger_process_uptime_seconds gauge"
          metrics << "passenger_process_uptime_seconds{#{labels}} #{process['uptime'] || 0}"
          
          # Spawn start time (Unix timestamp)
          metrics << "# HELP passenger_process_spawn_start_time_seconds Process spawn start time (Unix timestamp)"
          metrics << "# TYPE passenger_process_spawn_start_time_seconds gauge"
          metrics << "passenger_process_spawn_start_time_seconds{#{labels}} #{process['spawn_start_time'] || 0}"
          
          # Last used time (Unix timestamp) 
          metrics << "# HELP passenger_process_last_used_seconds Time when process was last used (Unix timestamp)"
          metrics << "# TYPE passenger_process_last_used_seconds gauge"
          metrics << "passenger_process_last_used_seconds{#{labels}} #{process['last_used'] || 0}"
          
          # Current requests count
          metrics << "# HELP passenger_process_requests Current number of requests"
          metrics << "# TYPE passenger_process_requests gauge"
          metrics << "passenger_process_requests{#{labels}} #{process['requests'] || 0}"
          
          # Has metrics flag (1 = has metrics, 0 = no metrics)
          has_metrics_value = (process['has_metrics'] == true || process['has_metrics'] == 'true') ? 1 : 0
          metrics << "# HELP passenger_process_has_metrics Whether process has metrics available (1=yes, 0=no)"
          metrics << "# TYPE passenger_process_has_metrics gauge"
          metrics << "passenger_process_has_metrics{#{labels}} #{has_metrics_value}"
        end
      end
    end
    
    metrics
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
