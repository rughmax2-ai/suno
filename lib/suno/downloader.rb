# frozen_string_literal: true

require "net/http"
require "uri"
require "fileutils"
require "securerandom"

module Suno
  class Downloader
    class Error < StandardError; end

    # Maximum length for the final filename (without extension)
    MAX_BASENAME_LENGTH = 80

    def initialize(song: nil)
      @song = song
    end

    def download(url, preferred_name: nil)
      raise Error, "URL is required" if url.nil? || url.to_s.strip.empty?

      validate_url!(url)

      filename = build_filename(preferred_name)
      directory = File.expand_path(Suno.config.storage_path)
      local_path = File.join(directory, filename)

      # Final safety check: ensure the resolved path stays inside the storage directory
      unless File.expand_path(local_path).start_with?(directory)
        raise Error, "Invalid path detected (possible path traversal)"
      end

      FileUtils.mkdir_p(directory)

      puts "⬇️  Downloading → #{filename}"

      download_file(url, local_path)

      {
        local_path: local_path,
        filename: filename,
        size: File.size(local_path),
        url: url
      }
    end

    private

    def validate_url!(url)
      uri = URI.parse(url)

      unless %w[http https].include?(uri.scheme)
        raise Error, "Only http and https URLs are allowed"
      end

      if uri.host.nil? || uri.host.strip.empty?
        raise Error, "Invalid URL: missing host"
      end
    rescue URI::InvalidURIError => e
      raise Error, "Invalid URL: #{e.message}"
    end

    def build_filename(preferred_name)
      base = preferred_name || @song&.title || "suno_#{Time.now.to_i}"

      safe = sanitize(base)

      # Prevent empty or dangerous results
      safe = "suno_#{SecureRandom.hex(4)}" if safe.empty? || safe == "." || safe == ".."

      # Enforce maximum length
      safe = safe[0...MAX_BASENAME_LENGTH]

      "#{safe}.mp3"
    end

    def sanitize(name)
      name.to_s
          .strip
          .gsub(/[^\w\s\-]/, "")      # allow only word chars, spaces, hyphens
          .gsub(/\s+/, "_")            # spaces → underscores
          .gsub(/_+", "_")             # collapse multiple underscores
          .gsub(/\A_+|_+\z/, "")       # trim leading/trailing underscores
          .downcase
    end

    def download_file(url, local_path)
      uri = URI.parse(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 15
      http.read_timeout = 90

      # Force SSL verification
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?

      request = Net::HTTP::Get.new(uri)

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Download failed with HTTP #{response.code}"
      end

      File.open(local_path, "wb") do |file|
        file.write(response.body)
      end
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "Download timed out: #{e.message}"
    rescue OpenSSL::SSL::SSLError => e
      raise Error, "SSL error during download: #{e.message}"
    rescue => e
      raise Error, "Download error: #{e.message}"
    end
  end
end
