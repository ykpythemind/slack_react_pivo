require 'dotenv/load'
require 'sinatra'

get '/' do
  "Hello World! #{ENV["TEST"]}"
end

post '/events' do
  # Extract the event payload from the request and parse the JSON
  request_data = JSON.parse(request.body.read)

  unless ENV['SLACK_VERIFICATION_TOKEN'] == request_data['token']
    halt 403, "Invalid Slack verification token received: #{request_data['token']}"
  end

  case request_data['type']
  when 'event_callback'
    # Get the Team ID and event data from the request object
    team_id = request_data['team_id']
    event_data = request_data['event']

    # Events have a "type" attribute included in their payload, allowing you to handle different
    # event payloads as needed.
    case event_data['type']
    when 'team_join'
      # Event handler for when a user joins a team
    else
      # In the event we receive an event we didn't expect, we'll log it and move on.
      puts "Unexpected event:\n"
      puts JSON.pretty_generate(request_data)
    end
    # Return HTTP status code 200 so Slack knows we've received the event
    status 200
  when 'url_verification'
    # When we receive a `url_verification` event, we need to
    # return the same `challenge` value sent to us from Slack
    # to confirm our server's authenticity.
    request_data['challenge']
  end
end
