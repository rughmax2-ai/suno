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
    # Finalization Pipeline
    # Download → Normalize → Tag → CoverArt
    # ============================================

    def finalize(raw_result, song)
      unless raw_result.is_a?(Hash)
        raise ProviderError, "Provider returned invalid result format"
      end

      result = {
        status: raw_result[:status] || "unknown",
        audio_url: raw_result[:audio_url],
        local_path: raw_result[:local_path],
        provider: raw_result[:provider] || @provider,
        generation_id: raw_result[:generation_id],
        raw: raw_result
      }

      # 1. Download
      if result[:local_path] && File.exist?(result[:local_path].to_s)
        # already local
      elsif result[:audio_url]
        require_relative "downloader" unless defined?(Suno::Downloader)

        downloader = Downloader.new(song: song)
        download_info = downloader.download(
          result[:audio_url],
          preferred_name: song.title
        )

        result[:local_path] = download_info[:local_path]
        result[:filename]   = download_info[:filename]
        result[:size]       = download_info[:size]
      else
        raise ProviderError, "No audio_url or local_path returned from provider"
      end

      # 2. Normalize
      run_normalization(result, song)

      # 3. Tag
      run_tagging(result, song)

      # 4. Cover Art
      run_cover_art(result, song)

      result[:status] = "ready"
      result
    end

    def run_normalization(result, song)
      return result unless result[:local_path] && File.exist?(result[:local_path])

      should_normalize = true
      if song.respond_to?(:post_process_config) && song.post_process_config.is_a?(Hash)
        should_normalize = song.post_process_config.fetch(:normalize, true)
      end

      if should_normalize
        require_relative "normalizer" unless defined?(Suno::Normalizer)

        begin
          Normalizer.new(result[:local_path]).process!
          result[:normalized] = true
        rescue => e
          warn "[Suno] Normalization failed: #{e.message}"
          result[:normalized] = false
          result[:normalization_error] = e.message
        end
      end

      result
    end

    def run_tagging(result, song)
      return result unless result[:local_path] && File.exist?(result[:local_path])

      should_tag = true
      tag_config = {}

      if song.respond_to?(:post_process_config) && song.post_process_config.is_a?(Hash)
        should_tag = song.post_process_config.fetch(:tag, true)
        tag_config = song.post_process_config.slice(
          :artist, :album, :genre, :year, :embed_prompt, :ai_disclosure, :title
        )
      end

      if should_tag
        require_relative "tagger" unless defined?(Suno::Tagger)

        begin
          Tagger.new(result[:local_path], song: song, config: tag_config).tag!
          result[:tagged] = true
        rescue => e
          warn "[Suno] Tagging failed: #{e.message}"
          result[:tagged] = false
          result[:tagging_error] = e.message
        end
      end

      result
    end

    def run_cover_art(result, song)
      return result unless result[:local_path] && File.exist?(result[:local_path])

      require_relative "cover_art" unless defined?(Suno::CoverArt)

      begin
        cover_path = CoverArt.generate(song)
        result[:cover_path] = cover_path

        # Embed the cover into the MP3
        embed_cover(result[:local_path], cover_path)
        result[:cover_embedded] = true
      rescue => e
        warn "[Suno] Cover art failed: #{e.message}"
        result[:cover_embedded] = false
        result[:cover_error] = e.message
      end

      result
    end

    def embed_cover(audio_path, cover_path)
      return unless File.exist?(audio_path) && File.exist?(cover_path)

      output = "#{audio_path}.with_cover.mp3"

      command = [
        Suno.config.ffmpeg_path,
        "-y",
        "-i", audio_path,
        "-i", cover_path,
        "-map", "0:a",
        "-map", "1",
        "-c", "copy",
        "-metadata:s:v", "title=Album cover",
        "-metadata:s:v", "comment=Cover (front)",
        "-disposition:v", "attached_pic",
        output
      ]

      success = system(*command, out: File::NULL, err: File::NULL)

      if success && File.exist?(output)
        FileUtils.mv(output, audio_path)
        puts "🖼️  Cover embedded into MP3"
      end
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
