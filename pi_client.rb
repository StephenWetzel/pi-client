require 'action_cable_client'
require 'dotenv/load'
Dotenv.load('/home/pi/pi_client/.env')
PI = ENV['PLATFORM'] == 'PI'
require 'rpi_gpio' if PI

# cron job reboots pi nightly
# cron job checks most recent ping every minute, pkill job and relaunch

EventMachine.run do
  Dotenv.load('/home/pi/pi_client/.env')
  latest_ping_timestamp = 0
  RPi::GPIO.set_numbering :board if PI # Use pin number printed on board
  THIS_DEVICE_GUID = ENV['DEVICE_GUID']
  PIN_NUM = 11
  puts "Device GUID: #{THIS_DEVICE_GUID}, Pin: #{PIN_NUM}, PI: #{PI}"
  base_url = "#{ENV['HTTP_AUTH_USER']}:#{ENV['HTTP_AUTH_PASS']}@#{ENV['CONTROLLER_URL']}"
  status_url = "http://#{base_url}/api/v1/event_logs/1"
  websocket_url = "wss://#{base_url}/cable/"
  puts "URL: #{websocket_url}"
  RPi::GPIO.setup PIN_NUM, as: :output if PI
  RPi::GPIO.set_low PIN_NUM if PI
  client = ActionCableClient.new(websocket_url, 'EventChannel')
  client.connected { puts 'successfully connected.' } # Required to trigger subscription

  # called whenever a message is received from the server
  client.received(false) do | message |
    if message['type'] && message['type'] == 'ping'
      # puts "#{Time.current} PING"
      latest_ping_timestamp = message['message']
      File.write('/ramdisk/ping', latest_ping_timestamp) if PI # an external job watches this file, and if the ping gets old it kills this script and reruns it
    else
      puts message
      device_guid = message['message']['device_guid']
      event_code = message['message']['event_code']
      state_code = message['message']['state_code']
      event_log_id = message['message']['event_log_id']

      if THIS_DEVICE_GUID == device_guid && state_code == 'ON'
        puts "Power ON"
        RPi::GPIO.set_high PIN_NUM if PI
        sleep(0.5)
        RPi::GPIO.set_low PIN_NUM if PI
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
    RPi::GPIO.clean_up if PI
  end

  client.errored do | message |
    puts "#{Time.current} ERROR"
    puts message
    RPi::GPIO.clean_up if PI
  end

  EM.add_periodic_timer(10) do
    if (Time.current.to_i - latest_ping_timestamp > 10) || !client.subscribed?
      puts "#{Time.current} No recent pings"
      RPi::GPIO.clean_up if PI
      abort("Disconnected, exiting...") # Ideally we would reconnect to the websocket, but I couldn't figure that out
      client.instance_variable_set("@_websocket_client", EventMachine::WebSocketClient.connect(client._uri))
      client.connected { puts "Attempting to reconnect..." }
      client.subscribed { puts "Subscribed" }
    end
    RPi::GPIO.set_low PIN_NUM if PI # Ensure pin never gets stuck HIGH
  end
end
