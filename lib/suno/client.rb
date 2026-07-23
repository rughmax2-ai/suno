# frozen_string_literal: true

module Suno
  class Client
    class Error < StandardError; end
    class ProviderError < Error; end
    class ConfigurationError < Error; end

    SUPPORTED_PROVIDERS = %i[stable_audio musicgen].freeze

    def initialize(provider: nil, fallback_provider: nil)
      @provider = (provider || Suno.config.provider || :stable_audio).to_sym
      @fallback_provider = (fallback_provider || Suno.config.fallback_provider)&.to_sym

      validate_providers!
    end

    # ============================================
    # Public API
    # ============================================

    def generate(song, max_retries: 1, **options)
      raise ArgumentError, "song must respond to #title" unless song.respond_to?(:title)

      attempt = 0

      begin
        attempt += 1
        result = call_provider(@provider, song, **options)
        finalize(result, song)
      rescue ProviderError => e
        if should_fallback?(attempt, max_retries)
          warn_fallback(e)
          result = call_provider(@fallback_provider, song, **options)
          finalize(result, song)
        else
          raise Error, "All providers failed. Last error: #{e.message}"
        end
      end
    end

    private

    # ============================================
    # Provider Dispatch
    # ============================================

    def call_provider(provider, song, **options)
      case provider
      when :stable_audio
        require_relative "stable_audio_client" unless defined?(Suno::StableAudioClient)
        StableAudioClient.new.generate(song, **options)
      when :musicgen
        require_relative "musicgen_client" unless defined?(Suno::MusicGenClient)
        MusicGenClient.new.generate(song, **options)
      else
        raise ConfigurationError, "Unsupported provider: #{provider}"
      end
    rescue LoadError => e
      raise ProviderError, "Provider '#{provider}' is not yet implemented: #{e.message}"
    rescue => e
      raise ProviderError, "#{provider} failed: #{e.message}"
    end

    # ============================================
    # Finalization (Download + Enrichment hooks)
    # ============================================

    def finalize(raw_result, song)
      # This method will later:
      # 1. Download the audio if only a URL is returned
      # 2. Run PostProcessor
      # 3. Generate and embed CoverArt
      #
      # For now we return a consistent shape so the rest of the system can build on it.

      unless raw_result.is_a?(Hash)
        raise ProviderError, "Provider returned invalid result format"
      end

      {
        status: raw_result[:status] || "unknown",
        audio_url: raw_result[:audio_url],
        local_path: raw_result[:local_path],
        provider: raw_result[:provider] || @provider,
        generation_id: raw_result[:generation_id],
        raw: raw_result
      }
    end

    # ============================================
    # Helpers
    # ============================================

    def validate_providers!
      unless SUPPORTED_PROVIDERS.include?(@provider)
        raise ConfigurationError, "Unsupported primary provider: #{@provider}"
      end

      if @fallback_provider && !SUPPORTED_PROVIDERS.include?(@fallback_provider)
        raise ConfigurationError, "Unsupported fallback provider: #{@fallback_provider}"
      end

      if @fallback_provider == @provider
        raise ConfigurationError, "Fallback provider cannot be the same as primary provider"
      end
    end

    def should_fallback?(attempt, max_retries)
      @fallback_provider && attempt <= max_retries
    end

    def warn_fallback(error)
      warn "[Suno] Primary provider (#{@provider}) failed: #{error.message}"
      warn "[Suno] Attempting fallback provider: #{@fallback_provider}"
    end
  end
end
