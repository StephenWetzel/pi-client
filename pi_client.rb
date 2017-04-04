require 'action_cable_client'
require 'dotenv/load'

# https://github.com/jwhitehorn/pi_piper
# https://github.com/ClockVapor/rpi_gpio

EventMachine.run do
  username = ENV['HTTP_AUTH_USER']
  password = ENV['HTTP_AUTH_PASS']
  uri = "wss://#{username}:#{password}@pi-controller.herokuapp.com/cable/"
  # uri = "ws://#{username}:#{password}@localhost:3000/cable/"
  puts "URL: #{uri}"
  client = ActionCableClient.new(uri, 'EventChannel')
  # the connected callback is required, as it triggers
  # the actual subscribing to the channel but it can just be
  # client.connected {}
  client.connected { puts 'successfully connected.' }

  # called whenever a message is received from the server
  client.received do | message |
    puts client.subscribed?
    puts message
    device_guid = message['message']['device_guid']
    event_code = message['message']['event_code']
    state_code = message['message']['state_code']
    event_log_id = message['message']['event_log_id']

    puts "Power ON"

    response_dt = Time.current
    client.perform('response', { response_dt: response_dt, response: "OK", event_log_id: event_log_id })
  end

  client.subscribed do
    puts "Subscribed hook"
  end

  client.disconnected do
    puts "DISCONNECTED"
    puts Time.current
    # refire connect
  end

  puts "After received"

  # while true
  # EM.next_tick do
  #   EventMachine::Synchrony.sleep(1)
  #   request_dt = Time.current
  #   puts "#{client.subscribed?} #{request_dt}"
  #   # client.perform('ping', { request_dt: request_dt })
  # end

  # adds to a queue that is purged upon receiving of
  # a ping from the server
  client.perform('response', { message: 'hello from amc' })
end