module Agents
  class MastodonPublishAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!

    description do
      <<-MD
      The Mastodon Publish Agent publishes status from the events it receives.

      To be able to use this Agent you need to authenticate with Mastodon in the [Applications](https://mastodon.social/settings/applications) section first.

      You must also specify a `status` parameter, you can use [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) to format the status.
      Additional parameters can be passed via `parameters`.

      Set `server` to send to the right server.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      If `output_mode` is set to `merge`, the emitted Event will be merged into the original contents of the received Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "id": "XXXXXXXXXXXXXXXXXX",
            "created_at": "2022-04-30T10:43:17.130Z",
            "in_reply_to_id": null,
            "in_reply_to_account_id": null,
            "sensitive": false,
            "spoiler_text": "",
            "visibility": "public",
            "language": "fr",
            "uri": "https://mastodon.social/users/toto/statuses/XXXXXXXXXXXXXXXXXX",
            "url": "https://mastodon.social/@toto/XXXXXXXXXXXXXXXXXX",
            "replies_count": 0,
            "reblogs_count": 0,
            "favourites_count": 0,
            "edited_at": null,
            "favourited": false,
            "reblogged": false,
            "muted": false,
            "bookmarked": false,
            "pinned": false,
            "content": "<p>test</p>",
            "reblog": null,
            "application": {
              "name": "huginn",
              "website": "https://toto.com"
            },
            "account": {
              "id": "XXXXXXXXXXXXXXXXXX",
              "username": "toto",
              "acct": "toto",
              "display_name": "toto",
              "locked": false,
              "bot": false,
              "discoverable": false,
              "group": false,
              "created_at": "2022-04-29T00:00:00.000Z",
              "note": "",
              "url": "https://mastodon.social/@toto",
              "avatar": "https://mastodon.social/avatars/original/missing.png",
              "avatar_static": "https://mastodon.social/avatars/original/missing.png",
              "header": "https://mastodon.social/headers/original/missing.png",
              "header_static": "https://mastodon.social/headers/original/missing.png",
              "followers_count": 0,
              "following_count": 0,
              "statuses_count": 1,
              "last_status_at": "2022-04-30",
              "emojis": [],
              "fields": []
            },
            "media_attachments": [],
            "mentions": [],
            "tags": [],
            "emojis": [],
            "card": null,
            "poll": null
          }
    MD

    def default_options
      {
        'status' => '',
        'server' => '',
        'access_token' => '',
        'debug' => 'false',
        'emit_events' => 'false',
        'expected_receive_period_in_days' => '2',
      }
    end

    form_configurable :access_token, type: :string
    form_configurable :status, type: :string
    form_configurable :server, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :emit_events, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    def validate_options

      unless options['access_token'].present?
        errors.add(:base, "access_token is a required field")
      end

      unless options['server'].present?
        errors.add(:base, "server is a required field")
      end

      unless options['status'].present?
        errors.add(:base, "status is a required field")
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          log event
          publish
        end
      end
    end

    def check
      publish
    end

    private

    def publish

      uri = URI.parse("https://#{interpolated['server']}/api/v1/statuses")
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(
        "status" => "#{interpolated['status']}",
      )
      request["Authorization"] = "Bearer #{interpolated['access_token']}"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      if interpolated['debug'] == 'true'
        log "response.body"
        log response.body
      end

      log "fetch status request status : #{response.code}"
      if interpolated['emit_events'] == 'true'
        create_event payload: response.body
      end
    end
  end
end
