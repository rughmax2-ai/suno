# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "shellwords"

module Suno
  class StableAudioClient
    BASE_URL = "https://api.stability.ai/v2beta"

    class Error < StandardError; end
    class TimeoutError < Error; end
    class APIError < Error; end
    class AuthenticationError < Error; end

    # Polling configuration
    POLL_INTERVAL = 10   # Stability recommends ≥ 10 seconds
    MAX_POLLS     = 60   # ~10 minutes max
    OPEN_TIMEOUT  = 15
    READ_TIMEOUT  = 60

    def initialize(api_key: nil)
      @api_key = api_key || ENV["STABILITY_API_KEY"]
      raise AuthenticationError, "STABILITY_API_KEY is not set" if @api_key.nil? || @api_key.strip.empty?
    end

    # ============================================
    # Public API
    # ============================================

    def generate(song, wait: true, **options)
      payload = build_payload(song, options)

      response = post_json("#{BASE_URL}/stable-audio/generate", payload)
      generation_id = response["id"]

      unless generation_id
        raise APIError, "No generation ID returned from Stable Audio"
      end

      return {
        status: "processing",
        generation_id: generation_id,
        provider: "stable_audio"
      } unless wait

      poll_until_ready(generation_id)
    end

    private

    # ============================================
    # Payload Construction
    # ============================================

    def build_payload(song, options)
      prompt = build_prompt(song)

      {
        prompt: prompt,
        duration: options[:duration] || 30,
        steps: options[:steps] || 50,
        cfg_scale: options[:cfg_scale] || 7.0,
        output_format: "mp3"
      }.compact
    end

    def build_prompt(song)
      parts = []
      parts << song.concept if song.respond_to?(:concept) && song.concept
      parts << "Style: #{song.style}" if song.respond_to?(:style) && song.style
      parts << "Structure: #{song.structure}" if song.respond_to?(:structure) && song.structure
      parts.join(". ").strip
    end

    # ============================================
    # HTTP Helpers
    # ============================================

    def post_json(url, body)
      uri = URI(url)
      http = build_http(uri)

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = body.to_json

      response = http.request(request)
      handle_response(response)
    end

    def get_json(url)
      uri = URI(url)
      http = build_http(uri)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Accept"] = "application/json"

      response = http.request(request)
      handle_response(response)
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http
    end

    def handle_response(response)
      code = response.code.to_i

      case code
      when 200..299
        JSON.parse(response.body)
      when 401, 403
        raise AuthenticationError, "Authentication failed (#{code}). Check your STABILITY_API_KEY."
      when 429
        raise APIError, "Rate limited by Stability AI (429). Please wait and retry."
      else
        raise APIError, "Stable Audio API error (#{code}): #{response.body}"
      end
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON response: #{e.message}"
    end

    # ============================================
    # Async Polling
    # ============================================

    def poll_until_ready(generation_id)
      delay = POLL_INTERVAL

      MAX_POLLS.times do |i|
        result = fetch_result(generation_id)

        case result[:status]
        when "completed", "ready"
          return result
        when "failed", "error"
          raise APIError, result[:message] || "Generation failed"
        end

        print "." if i > 0
        sleep delay
        delay = [delay * 1.3, 30].min
      end

      raise TimeoutError, "Generation timed out after #{MAX_POLLS * POLL_INTERVAL} seconds"
    end

    def fetch_result(generation_id)
      data = get_json("#{BASE_URL}/results/#{generation_id}")

      {
        status: data["status"] || "unknown",
        audio_url: data.dig("result", "audio_url") || data["audio_url"] || data.dig("output", "url"),
        generation_id: generation_id,
        provider: "stable_audio",
        message: data["error"] || data["message"]
      }
    end
  end
end
