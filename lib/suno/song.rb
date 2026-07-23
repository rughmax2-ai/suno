# frozen_string_literal: true

module Suno
  class Song
    attr_accessor :title, :concept, :style, :structure,
                  :post_process_config, :metadata, :vocal_style

    def self.build(&block)
      song = new
      song.instance_eval(&block) if block_given?
      song
    end

    def initialize
      @metadata = {}
      @post_process_config = {}
    end

    def title(value)
      @title = value
    end

    def concept(value)
      @concept = value
    end

    def style(value)
      @style = value
    end

    def structure(value)
      @structure = value
    end

    def vocal_style(value)
      @vocal_style = value
    end

    def post_process(&block)
      config = PostProcessConfig.new
      config.instance_eval(&block) if block_given?
      @post_process_config = config.to_h
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
  end

  # Nested configuration object for post-processing
  class PostProcessConfig
    def initialize
      @config = {}
    end

    def normalize(loudness: nil, fade_in: 0.5, fade_out: 2.0)
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
      @config[:organize] = true
      @config[:organize_by] = by
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
      @config[:artist] = value
    end

    def album(value)
      @config[:album] = value
    end

    def year(value)
      @config[:year] = value
    end

    def genre(value)
      @config[:genre] = value
    end

    def embed_prompt(value = true)
      @config[:embed_prompt] = value
    end

    def ai_disclosure(value = true)
      @config[:ai_disclosure] = value
    end

    def to_h
      @config
    end
  end
end
