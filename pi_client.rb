require 'action_cable_client'
require 'dotenv/load'
# require 'rpi_gpio'

# https://github.com/jwhitehorn/pi_piper
# https://github.com/ClockVapor/rpi_gpio
# cron job reboots pi nightly
# cron job checks most recent ping every minute, pkill job and relaunch


EventMachine.run do
  latest_ping_timestamp = 0
  # RPi::GPIO.set_numbering :board # Use pin number printed on board
  THIS_DEVICE_GUID = ENV['DEVICE_GUID']
  PIN_NUM = 11
  username = ENV['HTTP_AUTH_USER']
  password = ENV['HTTP_AUTH_PASS']
  uri = "wss://#{username}:#{password}@pi-controller.herokuapp.com/cable/"
  # uri = "ws://#{username}:#{password}@localhost:3000/cable/"
  puts "URL: #{uri}"
  # RPi::GPIO.setup PIN_NUM, as: :output
  # Pi::GPIO.set_low PIN_NUM
  client = ActionCableClient.new(uri, 'EventChannel')
  client.connected { puts 'successfully connected.' } # Required to trigger subscription

  # called whenever a message is received from the server
  client.received(false) do | message |
    if message['type'] && message['type'] == 'ping'
      # puts "#{Time.current} PING"
      latest_ping_timestamp = message['message']
      File.write('/ramdisk/ping', latest_ping_timestamp)
    else
      puts message
      device_guid = message['message']['device_guid']
      event_code = message['message']['event_code']
      state_code = message['message']['state_code']
      event_log_id = message['message']['event_log_id']

      if THIS_DEVICE_GUID == device_guid && state_code == 'ON'
        puts "Power ON"
        # Pi::GPIO.set_high PIN_NUM
        sleep(0.5)
        # Pi::GPIO.set_low PIN_NUM
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
      # RPi::GPIO.clean_up
      abort("Disconnected, exiting...")
      client.instance_variable_set("@_websocket_client", EventMachine::WebSocketClient.connect(client._uri))
      client.connected { puts "Attempting to reconnect..." }
      client.subscribed { puts "Subscribed" }
    end
    # Pi::GPIO.set_low PIN_NUM # Ensure pin never gets stuck HIGH
  end
end
