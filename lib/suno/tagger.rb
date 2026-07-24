# frozen_string_literal: true

require "shellwords"

module Suno
  class Tagger
    class Error < StandardError; end

    def initialize(file_path, song: nil, config: {})
      @file_path = file_path
      @song = song
      @config = config || {}
    end

    def tag!
      validate_input!

      tags = build_tags
      apply_tags(tags)

      puts "🎫  ID3 tags written"
      true
    end

    private

    def validate_input!
      unless File.exist?(@file_path)
        raise Error, "File does not exist: #{@file_path}"
      end
    end

    def build_tags
      tags = {}

      # Basic metadata
      tags[:title]  = @config[:title]  || @song&.title || File.basename(@file_path, ".*")
      tags[:artist] = @config[:artist] || Suno.config.default_artist
      tags[:album]  = @config[:album]  || Suno.config.default_album
      tags[:genre]  = @config[:genre]  || "AI Generated"
      tags[:year]   = @config[:year]   || Time.now.year.to_s

      # Provenance / AI disclosure
      comment_parts = []
      comment_parts << "AI Generated with Suno gem v#{Suno::VERSION}"

      if @config[:embed_prompt] && @song
        prompt_info = []
        prompt_info << "Concept: #{@song.concept}" if @song.concept
        prompt_info << "Style: #{@song.style}" if @song.style
        comment_parts << prompt_info.join(" | ") if prompt_info.any?
      end

      if @config.fetch(:ai_disclosure, true)
        comment_parts << "This track was generated with AI."
      end

      tags[:comment] = comment_parts.join(" \u2014 ")

      tags
    end

    def apply_tags(tags)
      # Prefer ffmpeg for reliability and minimal dependencies
      metadata_args = tags.flat_map do |key, value|
        ["-metadata", "#{key}=#{value}"]
      end

      output = "#{@file_path}.tagged.mp3"

      command = [
        Suno.config.ffmpeg_path,
        "-y",
        "-i", @file_path,
        *metadata_args,
        "-codec", "copy",
        output
      ]

      success = system(*command, out: File::NULL, err: File::NULL)

      unless success && File.exist?(output)
        raise Error, "Failed to write ID3 tags"
      end

      FileUtils.mv(output, @file_path)
    end
  end
end
