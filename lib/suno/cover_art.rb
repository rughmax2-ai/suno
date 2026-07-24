# frozen_string_literal: true

require "mini_magick"
require "fileutils"

module Suno
  class CoverArt
    class Error < StandardError; end

    # Artistic style library
    STYLES = {
      vaporwave: {
        colors: ["#FF71CE", "#01CDFE", "#05FFA1", "#B967FF"],
        mood: "neon retro futuristic"
      },
      dark_academia: {
        colors: ["#2C1810", "#5C4033", "#C4A484", "#8B7355"],
        mood: "moody scholarly vintage"
      },
      bauhaus: {
        colors: ["#E63946", "#F1FAEE", "#A8DADC", "#1D3557"],
        mood: "geometric primary shapes"
      },
      neo_noir: {
        colors: ["#0D0D0D", "#1A1A2E", "#E94560", "#16213E"],
        mood: "cinematic dark dramatic"
      },
      synthwave: {
        colors: ["#FF0080", "#7928CA", "#FF4D4D", "#00F5D4"],
        mood: "retro neon sunset"
      },
      minimal: {
        colors: ["#111111", "#EEEEEE", "#888888", "#444444"],
        mood: "clean minimalist"
      },
      surreal: {
        colors: ["#6B5B95", "#88B04B", "#F7CAC9", "#92A8D1"],
        mood: "dreamlike abstract"
      },
      cyberpunk: {
        colors: ["#00F0FF", "#FF00A0", "#0A0A0A", "#1A1A2E"],
        mood: "high-tech neon dystopian"
      }
    }.freeze

    def self.generate(song, output_path: nil, style: nil)
      new(song, output_path: output_path, style: style).generate
    end

    def initialize(song, output_path: nil, style: nil)
      @song = song
      @style_key = (style || detect_style).to_sym
      @style = STYLES[@style_key] || STYLES[:minimal]
      @output_path = output_path || default_output_path
    end

    def generate
      FileUtils.mkdir_p(File.dirname(@output_path))

      image = MiniMagick::Image.create do |f|
        f.write("PNG")
      end

      # Create base canvas
      image.combine_options do |c|
        c.size "1000x1000"
        c.xc @style[:colors].first
      end

      # Apply gradient background
      apply_gradient(image)

      # Add artistic texture / noise feel
      apply_texture(image)

      # Typography
      apply_typography(image)

      image.write(@output_path)

      puts "🎨  Cover art generated (#{@style_key}) → #{File.basename(@output_path)}"
      @output_path
    rescue => e
      raise Error, "Cover art generation failed: #{e.message}"
    end

    private

    def detect_style
      text = [
        @song.respond_to?(:style) ? @song.style : nil,
        @song.respond_to?(:concept) ? @song.concept : nil,
        @song.respond_to?(:title) ? @song.title : nil
      ].compact.join(" ").downcase

      return :cyberpunk if text.match?(/cyber|neon|futur|tech|glitch/)
      return :vaporwave if text.match?(/vapor|retro|80s|synth/)
      return :synthwave if text.match?(/synthwave|outrun|retrowave/)
      return :dark_academia if text.match?(/dark|academia|gothic|moody|rain/)
      return :neo_noir if text.match?(/noir|cinematic|shadow|night/)
      return :bauhaus if text.match?(/bauhaus|geometric|abstract|modernist/)
      return :surreal if text.match?(/dream|surreal|ethereal|abstract/)

      :minimal
    end

    def default_output_path
      base = @song.respond_to?(:title) && @song.title ? @song.title : "cover"
      safe = base.to_s.gsub(/[^\w\s\-]/, "").gsub(/\s+/, "_").downcase
      File.join(Suno.config.storage_path, "#{safe}_cover.png")
    end

    def apply_gradient(image)
      colors = @style[:colors]

      image.combine_options do |c|
        c.fill colors[1] || colors.first
        c.draw "rectangle 0,0 1000,1000"
        c.fill colors[2] || colors.first
        c.draw "rectangle 0,600 1000,1000"
      end
    end

    def apply_texture(image)
      # Subtle noise-like effect using attenuation
      image.combine_options do |c|
        c.attenuate 0.3
        c.noise "Gaussian"
      end
    rescue
      # Noise is optional — some ImageMagick builds differ
    end

    def apply_typography(image)
      title = @song.respond_to?(:title) ? @song.title.to_s : "Untitled"
      artist = Suno.config.default_artist

      # Title
      image.combine_options do |c|
        c.gravity "Center"
        c.pointsize 72
        c.fill "white"
        c.font "Helvetica-Bold"
        c.draw "text 0,-40 '#{escape(title)}'"
      end

      # Artist / subtitle
      image.combine_options do |c|
        c.gravity "Center"
        c.pointsize 28
        c.fill "#CCCCCC"
        c.font "Helvetica"
        c.draw "text 0,40 '#{escape(artist)}'"
      end

      # Style label
      image.combine_options do |c|
        c.gravity "South"
        c.pointsize 18
        c.fill "#AAAAAA"
        c.draw "text 0,30 '#{@style_key.to_s.tr("_", " ").upcase}'"
      end
    end

    def escape(text)
      text.to_s.gsub("'", "\\'")
    end
  end
end
