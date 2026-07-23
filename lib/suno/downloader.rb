# frozen_string_literal: true

require "net/http"
require "uri"
require "fileutils"

module Suno
  class Downloader
    class Error < StandardError; end

    def initialize(song: nil)
      @song = song
    end

    def download(url, preferred_name: nil)
      raise Error, "URL is required" if url.nil? || url.to_s.strip.empty?

      filename = build_filename(preferred_name)
      directory = Suno.config.storage_path
      local_path = File.join(directory, filename)

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

    def build_filename(preferred_name)
      base = preferred_name || @song&.title || "suno_#{Time.now.to_i}"
      safe = base.to_s
                .gsub(/[^\w\s\-]/, "")
                .gsub(/\s+/, "_")
                .downcase

      "#{safe}.mp3"
    end

    def download_file(url, local_path)
      uri = URI.parse(url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 15
      http.read_timeout = 90

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
    rescue => e
      raise Error, "Download error: #{e.message}"
    end
  end
end
