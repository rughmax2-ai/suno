# frozen_string_literal: true

require "suno/version"
require "suno/config"
require "suno/song"
require "suno/client"

module Suno
  class Error < StandardError; end

  class << self
    attr_accessor :config

    def configure
      self.config ||= Config.new
      yield(config) if block_given?
    end

    def reset!
      self.config = Config.new
    end
  end

  # Initialize with safe defaults
  configure

  # ============================================
  # UNIFIED HIGH-LEVEL API
  # ============================================
  def self.generate(song_or_title, **options)
    song = if song_or_title.is_a?(String)
             Song.build do
               title song_or_title
               concept options[:concept] if options[:concept]
               style options[:style] if options[:style]
             end
           else
             song_or_title
           end

    Client.new.generate(song, **options)
  end
end
