require 'action_cable_client'
require 'dotenv/load'

# https://github.com/jwhitehorn/pi_piper
# https://github.com/ClockVapor/rpi_gpio
# cron job reboots pi nightly
# cron job checks most recent ping every minute, pkill job and relaunch


EventMachine.run do
  latest_ping_timestamp = 0
  THIS_DEVICE_GUID = "0f0f4e02-ed27-448c-bfdb-3fcc6e5239d1"
  username = ENV['HTTP_AUTH_USER']
  password = ENV['HTTP_AUTH_PASS']
  uri = "wss://#{username}:#{password}@pi-controller.herokuapp.com/cable/"
  uri = "ws://#{username}:#{password}@localhost:3000/cable/"
  puts "URL: #{uri}"
  client = ActionCableClient.new(uri, 'EventChannel')
  client.connected { puts 'successfully connected.' } # Required to trigger subscription

  # called whenever a message is received from the server
  client.received(false) do | message |
    if message['type'] && message['type'] == 'ping'
      puts "#{Time.current} PING"
      latest_ping_timestamp = message['message']
    else
      puts message
      device_guid = message['message']['device_guid']
      event_code = message['message']['event_code']
      state_code = message['message']['state_code']
      event_log_id = message['message']['event_log_id']

      if THIS_DEVICE_GUID == device_guid && state_code == 'ON'
        puts "Power ON"
        response_dt = Time.current
        client.perform('response', { response_dt: response_dt, response: "OK", event_log_id: event_log_id, device_guid: THIS_DEVICE_GUID })
      end
    end
  end

  client.subscribed do
    puts "#{Time.current} Subscribed"
  end

  client.disconnected do
    puts "#{Time.current} DISCONNECTED"
    # refire connect
  end

  client.errored do | message |
    puts "#{Time.current} ERROR"
    puts message
  end

  EM.add_periodic_timer(10) do
    if (Time.current.to_i - latest_ping_timestamp > 10) || !client.subscribed?
      puts "#{Time.current} No recent pings"
      abort("Disconnected, exiting...")
      client.instance_variable_set("@_websocket_client", EventMachine::WebSocketClient.connect(client._uri))
      client.connected { puts "Attempting to reconnect..." }
      client.subscribed { puts "Subscribed" }
    end
  end
end
