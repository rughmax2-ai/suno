# frozen_string_literal: true

require "suno/version"
require "suno/config"

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
  #
  # This is the recommended entry point.
  # It will be expanded carefully as the generation pipeline matures.
  #
  def self.generate(song_or_title, **options)
    raise Error, "Generation pipeline is under careful construction. See README."
  end
end
