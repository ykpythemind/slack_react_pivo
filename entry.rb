require 'bundler/setup'

require 'dotenv'
require 'slack-ruby-client'
require 'sinatra'
require 'tracker_api'

Dotenv.load

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

$client = Slack::Web::Client.new

pivo_client = TrackerApi::Client.new(token: ENV['PIVOTAL_API_TOKEN'])
$project = pivo_client.project(ENV['PIVOTAL_PROJECT_ID'])

class ReactionAdded
  def self.call(event_data)
    reaction = event_data["reaction"]
    puts reaction

    channel = event_data.dig("item", "channel")
    ts = event_data.dig("item", "ts")
    return if channel.nil? || ts.nil?

    res = $client.channels_history(channel: channel)
    message = res.messages.select { |message| message.ts == ts }[0]
    return if message.blank?

    text = message.text
    puts text
    $project.create_story(name: text.slice(0, 40), description: text)
  end
end

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

    case event_data['type']
    when 'reaction_added'
      # Event handler for when a user joins a team
      ReactionAdded.call(event_data)
    else
      # In the event we receive an event we didn't expect, we'll log it and move on.
      # puts "Unexpected event:\n"
      # puts JSON.pretty_generate(request_data)
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
