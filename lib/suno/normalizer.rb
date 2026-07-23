# frozen_string_literal: true

require "streamio-ffmpeg"
require "fileutils"
require "json"

module Suno
  class Normalizer
    class Error < StandardError; end

    def initialize(file_path)
      @input = file_path
      @output = "#{file_path}.normalized.mp3"
    end

    def process!
      target_lufs = Suno.config.target_lufs
      true_peak   = Suno.config.true_peak
      lra         = Suno.config.loudness_range

      puts "🎛️  Two-pass loudness normalization → #{target_lufs} LUFS"

      analysis = analyze
      print_stats("BEFORE", analysis)

      apply_normalization(analysis, target_lufs, true_peak, lra)

      FileUtils.mv(@output, @input)

      final = analyze
      print_stats("AFTER", final)

      puts "✅ Normalization complete"
    end

    private

    def analyze
      command = [
        Suno.config.ffmpeg_path,
        "-i", @input,
        "-af", "loudnorm=print_format=json",
        "-f", "null",
        "-"
      ]

      output = `#{command.shelljoin} 2>&1`

      json_match = output.match(/\{[\s\S]*?\}/)
      return default_analysis unless json_match

      data = JSON.parse(json_match[0])

      {
        input_i:      data["input_i"]&.to_f || -18.0,
        input_tp:     data["input_tp"]&.to_f || -3.0,
        input_lra:    data["input_lra"]&.to_f || 12.0,
        input_thresh: data["input_thresh"]&.to_f || -25.0,
        offset:       data["target_offset"]&.to_f || 0.0
      }
    rescue
      default_analysis
    end

    def apply_normalization(analysis, target_lufs, true_peak, lra)
      filter = [
        "loudnorm=I=#{target_lufs}:TP=#{true_peak}:LRA=#{lra}",
        "measured_I=#{analysis[:input_i]}",
        "measured_TP=#{analysis[:input_tp]}",
        "measured_LRA=#{analysis[:input_lra]}",
        "measured_thresh=#{analysis[:input_thresh]}",
        "offset=#{analysis[:offset]}",
        "linear=true",
        "afade=t=in:st=0:d=0.5",
        "afade=t=out:st=duration-2:d=2.0"
      ].join(":")

      movie = FFmpeg::Movie.new(@input)

      movie.transcode(@output, {
        audio_codec: "libmp3lame",
        audio_bitrate: "320k",
        audio_filters: filter
      })
    rescue => e
      raise Error, "Normalization failed: #{e.message}"
    end

    def print_stats(label, analysis)
      puts "📊 #{label}:"
      puts "   Integrated Loudness : #{analysis[:input_i].round(2)} LUFS"
      puts "   True Peak           : #{analysis[:input_tp].round(2)} dBTP"
      puts "   Loudness Range      : #{analysis[:input_lra].round(2)} LU"
    end

    def default_analysis
      {
        input_i: -18.0,
        input_tp: -3.0,
        input_lra: 12.0,
        input_thresh: -25.0,
        offset: 0.0
      }
    end
  end
end
