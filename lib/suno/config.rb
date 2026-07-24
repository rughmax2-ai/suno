# frozen_string_literal: true

module Suno
  class Config
    attr_accessor :storage_path,
                  :ffmpeg_path,
                  :provider,
                  :fallback_provider,
                  :target_lufs,
                  :true_peak,
                  :loudness_range,
                  :fade_in,
                  :fade_out,
                  :default_artist,
                  :default_album

    # API keys are intentionally NOT stored as attributes here.
    # They must be provided via environment variables or
    # passed explicitly at runtime for security.

    def initialize
      @storage_path      = File.expand_path("~/Music/Suno")
      @ffmpeg_path       = "ffmpeg"
      @provider          = :stable_audio
      @fallback_provider = :musicgen

      # Professional loudness defaults (streaming standard)
      @target_lufs       = -14.0
      @true_peak         = -1.5
      @loudness_range    = 11.0

      # Fade defaults (seconds)
      @fade_in           = 0.5
      @fade_out          = 2.0

      @default_artist    = "AI Generated"
      @default_album     = "Suno Generations"
    end
  end
end
