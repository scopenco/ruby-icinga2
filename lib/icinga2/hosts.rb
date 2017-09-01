
# frozen_string_literal: true
module Icinga2

  # namespace for host handling
  module Hosts

    # add host
    #
    # @param [Hash] params
    # @option params [String] :host
    # @option params [String] :fqdn
    # @option params [String] :display_name
    # @option params [Bool] :enable_notifications (false)
    # @option params [Integer] :max_check_attempts (3)
    # @option params [Integer] :check_interval (60)
    # @option params [Integer] :retry_interval (45)
    # @option params [String] :notes
    # @option params [String] :notes_url
    # @option params [String] :action_url
    # @option params [Hash] :vars ({})
    #
    # @example
    #    param = {
    #      host: 'foo',
    #      fqdn: 'foo.bar.com',
    #      display_name: 'test node',
    #      max_check_attempts: 5,
    #      notes: 'test node'
    #    }
    #    @icinga.add_host(param)
    #
    # @return [Hash]
    #
    def add_host( params )

      raise ArgumentError.new('only Hash are allowed') unless( params.is_a?(Hash) )
      raise ArgumentError.new('missing params') if( params.size.zero? )

      host               = params.dig(:host)
      fqdn               = params.dig(:fqdn)
      display_name       = params.dig(:display_name) || host
      notifications      = params.dig(:enable_notifications) || false
      max_check_attempts = params.dig(:max_check_attempts) || 3
      check_interval     = params.dig(:check_interval) || 60
      retry_interval     = params.dig(:retry_interval) || 45
      notes              = params.dig(:notes)
      notes_url          = params.dig(:notes_url)
      action_url         = params.dig(:action_url)
      vars               = params.dig(:vars) || {}

      raise ArgumentError.new('Missing host') if( host.nil? )
      raise ArgumentError.new('only true or false for notifications are allowed') unless( notifications.is_a?(TrueClass) || notifications.is_a?(FalseClass) )
      raise ArgumentError.new('only Integer for max_check_attempts are allowed') unless( max_check_attempts.is_a?(Integer) )
      raise ArgumentError.new('only Integer for check_interval are allowed') unless( check_interval.is_a?(Integer) )
      raise ArgumentError.new('only Integer for retry_interval are allowed') unless( retry_interval.is_a?(Integer) )
      raise ArgumentError.new('only String for notes are allowed') unless( notes.is_a?(String) || notes.nil? )
      raise ArgumentError.new('only String for notes_url are allowed') unless( notes_url.is_a?(String) || notes_url.nil? )
      raise ArgumentError.new('only Hash for vars are allowed') unless( vars.is_a?(Hash) )

      if( fqdn.nil? )
        # build FQDN
        fqdn = Socket.gethostbyname( host ).first
      end

      payload = {
        'templates' => [ 'generic-host' ],
        'attrs'     => {
          'address'              => fqdn,
          'display_name'         => display_name,
          'max_check_attempts'   => max_check_attempts.to_i,
          'check_interval'       => check_interval.to_i,
          'retry_interval'       => retry_interval.to_i,
          'enable_notifications' => notifications,
          'action_url'           => action_url,
          'notes'                => notes,
          'notes_url'            => notes_url
        }
      }

      payload['attrs']['vars'] = vars unless  vars.empty?

      if( @icinga_cluster == true && !@icinga_satellite.nil? )
        payload['attrs']['zone'] = @icinga_satellite
      end

      # logger.debug( JSON.pretty_generate( payload ) )

      Network.put(
        url: format( '%s/objects/hosts/%s', @icinga_api_url_base, host ),
        headers: @headers,
        options: @options,
        payload: payload
      )
    end

    # delete a host
    #
    # @param [Hash] params
    # @option params [String] :host host to delete
    #
    # @example
    #   @icinga.delete_host(host: 'foo')
    #
    # @return [Hash] result
    #
    def delete_host( params )

      raise ArgumentError.new('only Hash are allowed') unless( params.is_a?(Hash) )
      raise ArgumentError.new('missing params') if( params.size.zero? )

      host = params.dig(:host)

      raise ArgumentError.new('Missing host') if( host.nil? )

      Network.delete(
        url: format( '%s/objects/hosts/%s?cascade=1', @icinga_api_url_base, host ),
        headers: @headers,
        options: @options
      )
    end

    # currently not working
    #
    # The issue still stands and is not an easy one to solve: https://github.com/Icinga/icinga2/issues/4084
    # hand in hand with https://github.com/Icinga/icinga2/issues/4625
    #
    def modify_host( params )

      url = "https://monitoring-portal.org/index.php?thread/40717-update-host-vars-through-api-and-apply-service/&postID=249136#post249136"

      raise( format( 'please read %s for more informaton', ul ) )
    end

    # return hosts
    #
    # @param [Hash] params
    # @option params [String] :host
    # @option params [String] :attrs
    # @option params [String] :filter
    # @option params [String] :joins
    #
    # @example to get all hosts
    #    @icinga.hosts
    #
    # @example to get one host
    #    @icinga.hosts(host: 'icinga2')
    #
    # @return [Array]
    #
    def hosts( params = {} )

      host   = params.dig(:host)
      attrs  = params.dig(:attrs)
      filter = params.dig(:filter)
      joins  = params.dig(:joins)

      payload['attrs']  = attrs  unless attrs.nil?
      payload['filter'] = filter unless filter.nil?
      payload['joins']  = joins  unless joins.nil?

      data = Network.api_data(
        url: format( '%s/objects/hosts/%s', @icinga_api_url_base, host ),
        headers: @headers,
        options: @options
      )

      return data.dig('results') if( data.dig(:status).nil? )

      nil
    end

    # returns true if the host exists
    #
    # @param [String] host_name
    #
    # @example
    #    @icinga.exists_host?('icinga2')
    #
    # @return [Bool]
    #
    def exists_host?( host_name )

      raise ArgumentError.new('only String are allowed') unless( host_name.is_a?(String) )
      raise ArgumentError.new('Missing host_name') if( host_name.size.zero? )

      result = hosts( host: host_name )
      result = JSON.parse( result ) if  result.is_a?( String )

      return true if  !result.nil? && result.is_a?(Array)

      false
    end

    # returns host objects
    #
    # @param [Hash] params
    # @option params [Array] :attrs (['name', 'state', 'acknowledgement', 'downtime_depth', 'last_check'])
    # @option params [Array] :filter ([])
    # @option params [Array] :joins ([])
    #
    # @example with default attrs and joins
    #    @icinga.host_objects
    #
    # @example
    #    @icinga.host_objects(attrs: ['name', 'state'])
    #
    # @return [Hash]
    #
    def host_objects( params = {} )

      attrs   = params.dig(:attrs)
      filter  = params.dig(:filter)
      joins   = params.dig(:joins)

#       raise ArgumentError.new('only Array for attrs are allowed') unless( attrs.is_a?(Hash) )
#       raise ArgumentError.new('only Array for filter are allowed') unless( filter.is_a?(Hash) )
#       raise ArgumentError.new('only Array for joins are allowed') unless( joins.is_a?(Hash) )

      payload = {}
      results = nil

      if( attrs.nil? )
        attrs = %w[name state acknowledgement downtime_depth last_check]
      end

      payload['attrs']  = attrs  unless attrs.nil?
      payload['filter'] = filter unless filter.nil?
      payload['joins']  = joins  unless joins.nil?

      data = Network.api_data(
        url: format( '%s/objects/hosts', @icinga_api_url_base ),
        headers: @headers,
        options: @options,
        payload: payload
      )

      status  = data.dig(:status)

      if( status.nil? )

        results = data.dig('results')

        unless( results.nil? )

          all_hosts = results.clone

          unless( all_hosts.nil? )

            # global var for count of all hosts
            @hosts_all           = all_hosts.size
            # global var for count of all host with a problem
            @hosts_problems      = count_problems(results)
            # global var for count of all gost with state HOSTS_DOWN
            @hosts_problems_down     = count_problems(results, Icinga2::HOSTS_DOWN)
            @hosts_problems_critical = count_problems(results, Icinga2::HOSTS_CRITICAL)
            @hosts_problems_unknown  = count_problems(results, Icinga2::HOSTS_UNKNOWN)

          end
        end
      end

      results
    end

    # returns adjusted hosts state
    #
    # @example
    #    @icinga.cib_data
    #    @icinga.host_objects
    #    handled, down = @icinga.hosts_adjusted.values
    #
    #    h = @icinga.hosts_adjusted
    #    down = h.dig(:down_adjusted)
    #
    # @return [Hash]
    #    * handled_problems
    #    * down_adjusted
    #
    def hosts_adjusted

      raise ArgumentError.new('Integer for @hosts_problems_down needed') unless( @hosts_problems_down.is_a?(Integer) )
      raise ArgumentError.new('Integer for @hosts_problems_critical needed') unless( @hosts_problems_critical.is_a?(Integer) )
      raise ArgumentError.new('Integer for @hosts_problems_unknown needed') unless( @hosts_problems_unknown.is_a?(Integer) )
      raise ArgumentError.new('Integer for @hosts_down needed') unless( @hosts_down.is_a?(Integer) )

      # calculate host problems adjusted by handled problems
      # count togther handled host problems
      handled_problems = @hosts_problems_down + @hosts_problems_critical + @hosts_problems_unknown
      down_adjusted    = @hosts_down - handled_problems

      {
        handled_problems: handled_problems.to_i,
        down_adjusted: down_adjusted.to_i
      }
    end

    # return count of hosts with problems
    #
    # @example
    #    @icinga.count_hosts_with_problems
    #
    # @return [Integer]
    #
    def count_hosts_with_problems

      host_data = host_objects
      host_data = JSON.parse(host_data) if  host_data.is_a?(String)

      f = host_data.select { |t| t.dig('attrs','state') != 0 && t.dig('attrs','downtime_depth').zero? && t.dig('attrs','acknowledgement').zero? }

      f.size
    end

    # return a list of hosts with problems
    #
    # @param [Integer] max_items numbers of list entries
    #
    # @example
    #    @icinga.list_hosts_with_problems
    #
    # @return [Hash]
    #
    def list_hosts_with_problems( max_items = 5 )

      raise ArgumentError.new('only Integer for max_items are allowed') unless( max_items.is_a?(Integer) )

      host_problems = {}
      host_problems_severity = {}

      host_data = host_objects
      host_data = JSON.parse( host_data ) if host_data.is_a?(String)

      unless( host_data.nil? )

        host_data.each do |h,_v|
          name  = h.dig('name')
          state = h.dig('attrs','state')

          next if state.to_i.zero?

          host_problems[name] = host_severity(h)
        end
      end

      # get the count of problems
      #
      if( host_problems.count != 0 )
        host_problems.keys[1..max_items].each { |k,_v| host_problems_severity[k] = host_problems[k] }
      end

      host_problems_severity
    end

    # returns a counter of all hosts
    #
    # @example
    #    @icinga.host_objects
    #    @icinga.hosts_all
    #
    # @return [Integer]
    #
    def hosts_all
      @hosts_all
    end

    # returns data with host problems
    #
    # @example
    #    @icinga.host_objects
    #    all, down, critical, unknown = @icinga.host_problems.values
    #
    #    p = @icinga.host_problems
    #    down = h.dig(:down)
    #
    # @return [Hash]
    #    * all
    #    * down
    #    * critical
    #    * unknown
    #
    def host_problems

      problems_all      = @hosts_problems.nil?           ? 0 : @hosts_problems
      problems_down     = @hosts_problems_down.nil?      ? 0 : @hosts_problems_down
      problems_critical = @hosts_problems_critical.nil?  ? 0 : @hosts_problems_critical
      problems_unknown  = @hosts_problems_unknown.nil?   ? 0 : @hosts_problems_unknown

      {
        all: problems_all.to_i,
        down: problems_down.to_i,
        critical: problems_critical.to_i,
        unknown: problems_unknown.to_i
      }
    end

    protected
    # calculate a host severity
    #
    # stolen from Icinga Web 2
    # ./modules/monitoring/library/Monitoring/Backend/Ido/Query/ServicestatusQuery.php
    #
    # @param [Hash] params
    # @option params [hash] attrs ()
    #   * state [Float]
    #   * acknowledgement [Float] (default: 0)
    #   * downtime_depth [Float] (default: 0)
    #
    # @api protected
    #
    # @example
    #   host_severity( {'attrs' => { 'state' => 0.0, 'acknowledgement' => 0.0, 'downtime_depth' => 0.0 } } )
    #
    # @return [Integer]
    #
    def host_severity( params )

      raise ArgumentError.new('only Hash are allowed') unless( params.is_a?(Hash) )
      raise ArgumentError.new('missing params') if( params.size.zero? )

      state           = params.dig('attrs','state')
      acknowledgement = params.dig('attrs','acknowledgement') || 0
      downtime_depth  = params.dig('attrs','downtime_depth')  || 0

      raise ArgumentError.new('only Float for state are allowed') unless( state.is_a?(Float) )
      raise ArgumentError.new('only Float for acknowledgement are allowed') unless( acknowledgement.is_a?(Float) )
      raise ArgumentError.new('only Float for downtime_depth are allowed') unless( downtime_depth.is_a?(Float) )

      severity = 0

      severity +=
        if acknowledgement != 0
          2
        elsif downtime_depth > 0
          1
        else
          4
        end

      severity += 16 if object_has_been_checked?(params)

      unless state.zero?

        severity +=
          if state == 1
            32
          elsif state == 2
            64
          else
            256
          end
      end

      severity
    end

  end
end
