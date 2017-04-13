Pi Websockets Client
====

## Intro
The idea behind this project is to control devices by physically wiring them to Raspberry Pis.  This client is designed to subscribe to a [websocket API](https://github.com/StephenWetzel/pi-controller) I built, and respond to events that are broadcast by it.

My current use case is a Raspberry Pi Zero W with pin 11 wired up to the base of a transistor that shorts a normally open push button switch, thus turning it on.

## Notes
I'm using [this gem](https://github.com/NullVoxPopuli/action_cable_client) for websockets clients.  It works well, but doesn't seem to support reconnecting when a connection is lost.  My work around for this is to write the timestamp from each ping to a file.  I then have a separate bash script (check_ping.sh) with runs every minute via cron and checks for the age of the last ping.  If it's old it'll kill this process and relaunch.  Not terrible elegant, but it works well, and makes the client rather robust.  Lastly, I set the Pi to restart every night at 3am via cron.

I launch the ruby script on boot via @reboot cron.  The check_ping.sh will also start it up, but there will be a longer delay.

## Example .env file
```
HTTP_AUTH_USER=username
HTTP_AUTH_PASS=password
CONTROLLER_URL=localhost:3000
DEVICE_GUID=1234
PLATFORM=PC
```
These values have to match those set in the API.  The device_guid will vary for each device, and is created by the API.  PLATFORM=PC is for dev, and turns off all the GPIO pin stuff; set it to PLATFORM=PI for prod.