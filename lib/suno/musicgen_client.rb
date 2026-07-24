# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Suno
  class MusicGenClient
    BASE_URL = "https://api.replicate.com/v1"

    # Official Meta MusicGen model on Replicate
    MODEL_VERSION = "meta/musicgen:7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906"

    class Error < StandardError; end
    class TimeoutError < Error; end
    class APIError < Error; end
    class AuthenticationError < Error; end

    POLL_INTERVAL = 5
    MAX_POLLS     = 72   # ~6 minutes
    OPEN_TIMEOUT  = 15
    READ_TIMEOUT  = 60

    def initialize(api_key: nil)
      @api_key = api_key || ENV["REPLICATE_API_TOKEN"]
      raise AuthenticationError, "REPLICATE_API_TOKEN is not set" if @api_key.nil? || @api_key.strip.empty?
    end

    # ============================================
    # Public API
    # ============================================

    def generate(song, wait: true, **options)
      payload = build_payload(song, options)

      response = post_json("#{BASE_URL}/predictions", payload)
      prediction_id = response["id"]

      unless prediction_id
        raise APIError, "No prediction ID returned from Replicate"
      end

      return {
        status: "processing",
        generation_id: prediction_id,
        provider: "musicgen"
      } unless wait

      poll_until_ready(prediction_id)
    end

    private

    # ============================================
    # Payload
    # ============================================

    def build_payload(song, options)
      {
        version: MODEL_VERSION,
        input: {
          prompt: build_prompt(song),
          duration: options[:duration] || 30,
          model_version: options[:model_version] || "stereo-large",
          output_format: "mp3"
        }
      }
    end

    def build_prompt(song)
      parts = []
      parts << song.concept if song.respond_to?(:concept) && song.concept
      parts << "Style: #{song.style}" if song.respond_to?(:style) && song.style
      parts << "Structure: #{song.structure}" if song.respond_to?(:structure) && song.structure
      parts.join(". ").strip
    end

    # ============================================
    # HTTP
    # ============================================

    def post_json(url, body)
      uri = URI(url)
      http = build_http(uri)

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Token #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Prefer"] = "wait"  # optional, Replicate supports this
      request.body = body.to_json

      response = http.request(request)
      handle_response(response)
    end

    def get_json(url)
      uri = URI(url)
      http = build_http(uri)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Token #{@api_key}"

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
        raise AuthenticationError, "Authentication failed (#{code}). Check your REPLICATE_API_TOKEN."
      when 429
        raise APIError, "Rate limited by Replicate (429). Please wait and retry."
      else
        raise APIError, "Replicate API error (#{code}): #{response.body}"
      end
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON response: #{e.message}"
    end

    # ============================================
    # Polling
    # ============================================

    def poll_until_ready(prediction_id)
      delay = POLL_INTERVAL

      MAX_POLLS.times do |i|
        data = get_json("#{BASE_URL}/predictions/#{prediction_id}")
        status = data["status"]

        case status
        when "succeeded"
          output = data["output"]
          audio_url = output.is_a?(Array) ? output.first : output

          return {
            status: "ready",
            audio_url: audio_url,
            generation_id: prediction_id,
            provider: "musicgen"
          }
        when "failed", "canceled"
          raise APIError, data["error"] || "MusicGen generation failed"
        end

        print "." if i > 0
        sleep delay
        delay = [delay * 1.2, 20].min
      end

      raise TimeoutError, "MusicGen generation timed out"
    end
  end
end
