# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "securerandom"
require "time"

require_relative "zerodrop/version"

# ZeroDrop — disposable email inboxes for testing auth flows in CI.
# OTPs and magic links auto-extracted at Cloudflare's edge.
# No regex, no Docker, no signup.
#
#   mail = ZeroDrop::Client.new
#   inbox = mail.generate_inbox
#   email = mail.wait_for_latest(inbox, timeout: 15)
#   email.otp        # => "847291"
#   email.magic_link # => "https://..."
module ZeroDrop
  DEFAULT_BASE_URL = "https://zerodrop.dev"
  FREE_DOMAIN = "zerodrop-sandbox.online"
  ADJECTIVES = %w[swift dark cold null void zero dead raw base core].freeze

  # Raised when no email arrives within the timeout.
  class TimeoutError < StandardError
    def initialize(inbox, timeout)
      super("no email received at #{inbox.inspect} within #{timeout}s — " \
            "check that your app is sending to the correct address")
    end
  end

  # Raised when an invalid API key is provided.
  class AuthError < StandardError
    def initialize
      super("invalid or missing API key")
    end
  end

  # Raised on transport-level failures.
  class NetworkError < StandardError; end

  # A caught email with auto-extracted fields.
  Email = Struct.new(
    :id, :from, :to, :subject, :body, :raw_body, :received_at,
    :otp, :magic_link,
    keyword_init: true
  )

  # Filter for narrowing which email is returned.
  # All string matches are case-insensitive partial matches.
  Filter = Struct.new(
    :from, :subject, :body, :has_otp, :has_magic_link,
    keyword_init: true
  ) do
    def matches?(email)
      return false if from && !email.from.to_s.downcase.include?(from.downcase)
      return false if subject && !email.subject.to_s.downcase.include?(subject.downcase)
      return false if body && !email.body.to_s.downcase.include?(body.downcase)

      unless has_otp.nil?
        return false if has_otp && email.otp.to_s.empty?
        return false if !has_otp && !email.otp.to_s.empty?
      end

      unless has_magic_link.nil?
        return false if has_magic_link && email.magic_link.to_s.empty?
        return false if !has_magic_link && !email.magic_link.to_s.empty?
      end

      true
    end
  end

  # The ZeroDrop API client.
  class Client
    # @param api_key [String, nil] Workspace API key. Omit for free sandbox mode.
    # @param base_url [String] Override for self-hosted instances.
    def initialize(api_key: nil, base_url: DEFAULT_BASE_URL)
      @api_key = api_key
      @base_url = base_url.chomp("/")
    end

    # Returns a ready-to-use email address instantly.
    # No network request is made.
    #
    # @return [String] e.g. "swift-x7k29ab@zerodrop-sandbox.online"
    def generate_inbox
      adjective = ADJECTIVES.sample
      suffix = SecureRandom.alphanumeric(7).downcase
      "#{adjective}-#{suffix}@#{FREE_DOMAIN}"
    end

    # Returns the newest email matching the filter, or nil.
    #
    # @param inbox [String] inbox address or name
    # @param filter [ZeroDrop::Filter, nil]
    # @return [ZeroDrop::Email, nil]
    def fetch_latest(inbox, filter: nil)
      name = inbox_name(inbox)
      uri = URI("#{@base_url}/api/inbox/#{name}?source=ruby-sdk")

      res = http_get(uri)
      raise AuthError if res.code == "401"
      raise NetworkError, "API returned #{res.code}" unless res.code == "200"

      payload = JSON.parse(res.body)
      emails = payload.fetch("emails", [])

      emails.each do |raw|
        email = build_email(raw)
        return email if filter.nil? || filter.matches?(email)
      end
      nil
    rescue JSON::ParserError => e
      raise NetworkError, "invalid response: #{e.message}"
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => e
      raise NetworkError, "#{e.message} (check https://zerodrop.instatus.com)"
    end

    # Blocks until an email matching the filter arrives.
    # Polls every `poll_interval` seconds up to `timeout` seconds.
    #
    # @param inbox [String] inbox address or name
    # @param timeout [Numeric] seconds to wait (default 10)
    # @param poll_interval [Numeric] seconds between polls (default 2)
    # @param filter [ZeroDrop::Filter, nil]
    # @return [ZeroDrop::Email]
    # @raise [ZeroDrop::TimeoutError] if nothing arrives in time
    def wait_for_latest(inbox, timeout: 10, poll_interval: 2, filter: nil)
      deadline = Time.now + timeout

      loop do
        email = fetch_latest(inbox, filter: filter)
        return email if email

        raise TimeoutError.new(inbox, timeout) if Time.now + poll_interval > deadline

        sleep poll_interval
      end
    end

    private

    def http_get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{@api_key}" if @api_key
      req["User-Agent"] = "zerodrop-ruby/#{VERSION}"

      http.request(req)
    end

    def build_email(raw)
      Email.new(
        id: raw["id"],
        from: raw["from"],
        to: raw["to"],
        subject: raw["subject"],
        body: extract_body(raw["raw"]),
        raw_body: raw["raw"],
        received_at: parse_time(raw["receivedAt"]),
        otp: raw["otp"].to_s.empty? ? nil : raw["otp"],
        magic_link: raw["magicLink"].to_s.empty? ? nil : raw["magicLink"]
      )
    end

    def parse_time(str)
      Time.parse(str) if str
    rescue ArgumentError, TypeError
      nil
    end

    def extract_body(raw)
      return "" if raw.nil? || raw.empty?

      if (m = raw.match(%r{Content-Type: text/plain[^\r\n]*\r\n\r\n(.*?)(?:\r\n--|\r\n\r\n--)}m))
        return m[1].strip
      end

      parts = raw.split("\r\n\r\n", 2)
      return "" unless parts.length == 2

      body = parts[1].strip
      body.length > 5000 ? body[0, 5000] : body
    end

    def inbox_name(inbox)
      name = inbox.include?("@") ? inbox.split("@").first : inbox
      name.downcase
    end
  end
end
