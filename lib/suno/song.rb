# frozen_string_literal: true

module Suno
  class Song
    class ValidationError < StandardError; end

    attr_accessor :title, :concept, :style, :structure,
                  :post_process_config, :metadata, :vocal_style

    def self.build(&block)
      song = new
      song.instance_eval(&block) if block_given?
      song.validate!
      song
    end

    def initialize
      @metadata = {}
      @post_process_config = {}
    end

    def title(value)
      @title = sanitize_string(value, field: "title", max: 120)
    end

    def concept(value)
      @concept = sanitize_string(value, field: "concept", max: 1000, allow_blank: true)
    end

    def style(value)
      @style = sanitize_string(value, field: "style", max: 200, allow_blank: true)
    end

    def structure(value)
      @structure = sanitize_string(value, field: "structure", max: 200, allow_blank: true)
    end

    def vocal_style(value)
      @vocal_style = sanitize_string(value, field: "vocal_style", max: 200, allow_blank: true)
    end

    def post_process(&block)
      config = PostProcessConfig.new
      config.instance_eval(&block) if block_given?
      @post_process_config = config.to_h
    end

    def validate!
      if @title.nil? || @title.strip.empty?
        raise ValidationError, "Song title is required"
      end

      if @title.length > 120
        raise ValidationError, "Song title is too long (max 120 characters)"
      end

      true
    end

    def to_h
      {
        title: @title,
        concept: @concept,
        style: @style,
        structure: @structure,
        vocal_style: @vocal_style,
        post_process_config: @post_process_config,
        metadata: @metadata
      }
    end

    private

    def sanitize_string(value, field:, max:, allow_blank: false)
      if value.nil?
        return nil if allow_blank
        raise ValidationError, "#{field} cannot be nil"
      end

      str = value.to_s.strip

      if str.empty? && !allow_blank
        raise ValidationError, "#{field} cannot be blank"
      end

      if str.length > max
        raise ValidationError, "#{field} is too long (max #{max} characters)"
      end

      # Basic control character filtering
      str = str.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

      str
    end
  end

  # Nested configuration object for post-processing
  class PostProcessConfig
    def initialize
      @config = {}
    end

    def normalize(loudness: nil, fade_in: 0.5, fade_out: 2.0)
      if loudness && !(loudness.is_a?(Numeric) && loudness.between?(-30, 0))
        raise Song::ValidationError, "loudness must be a number between -30 and 0"
      end

      if fade_in && !(fade_in.is_a?(Numeric) && fade_in >= 0 && fade_in <= 10)
        raise Song::ValidationError, "fade_in must be between 0 and 10 seconds"
      end

      if fade_out && !(fade_out.is_a?(Numeric) && fade_out >= 0 && fade_out <= 15)
        raise Song::ValidationError, "fade_out must be between 0 and 15 seconds"
      end

      @config[:normalize] = true
      @config[:loudness] = loudness if loudness
      @config[:fade_in] = fade_in
      @config[:fade_out] = fade_out
    end

    def tag(&block)
      tag_config = TagConfig.new
      tag_config.instance_eval(&block) if block_given?
      @config.merge!(tag_config.to_h)
      @config[:tag] = true
    end

    def organize(by: :album)
      allowed = %i[album year artist flat]
      unless allowed.include?(by.to_sym)
        raise Song::ValidationError, "organize by must be one of: #{allowed.join(', ')}"
      end

      @config[:organize] = true
      @config[:organize_by] = by.to_sym
    end

    def to_h
      @config
    end
  end

  class TagConfig
    def initialize
      @config = {}
    end

    def artist(value)
      @config[:artist] = sanitize(value, "artist", 100)
    end

    def album(value)
      @config[:album] = sanitize(value, "album", 100)
    end

    def year(value)
      year = value.to_i
      unless year.between?(1900, Time.now.year + 1)
        raise Song::ValidationError, "year must be a reasonable value"
      end
      @config[:year] = year
    end

    def genre(value)
      @config[:genre] = sanitize(value, "genre", 50)
    end

    def embed_prompt(value = true)
      @config[:embed_prompt] = !!value
    end

    def ai_disclosure(value = true)
      @config[:ai_disclosure] = !!value
    end

    def to_h
      @config
    end

    private

    def sanitize(value, field, max)
      str = value.to_s.strip
      raise Song::ValidationError, "#{field} cannot be blank" if str.empty?
      raise Song::ValidationError, "#{field} is too long" if str.length > max
      str.gsub(/[\x00-\x1F\x7F]/, "")
    end
  end
end
