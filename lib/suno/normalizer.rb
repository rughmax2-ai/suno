# frozen_string_literal: true

require "streamio-ffmpeg"
require "fileutils"
require "json"
require "shellwords"

module Suno
  class Normalizer
    class Error < StandardError; end

    def initialize(file_path, keep_original: true)
      @input = file_path
      @output = "#{file_path}.normalized.mp3"
      @keep_original = keep_original
    end

    # ============================================
    # Public API
    # ============================================

    def process!
      validate_input!

      target_lufs = Suno.config.target_lufs
      true_peak   = Suno.config.true_peak
      lra         = Suno.config.loudness_range
      fade_in     = Suno.config.respond_to?(:fade_in) ? Suno.config.fade_in : 0.5
      fade_out    = Suno.config.respond_to?(:fade_out) ? Suno.config.fade_out : 2.0

      puts "🎛️  Two-pass loudness normalization → #{target_lufs} LUFS"

      analysis = analyze
      print_stats("BEFORE", analysis)

      duration = probe_duration
      apply_normalization(analysis, target_lufs, true_peak, lra, fade_in, fade_out, duration)

      # Optionally keep the original file as backup
      if @keep_original
        backup_path = "#{@input}.original.mp3"
        FileUtils.cp(@input, backup_path) unless File.exist?(backup_path)
        puts "💾 Original backed up → #{File.basename(backup_path)}"
      end

      FileUtils.mv(@output, @input)

      final = analyze
      print_stats("AFTER", final)

      puts "✅ Normalization complete"
      true
    end

    # Analysis only — does not modify the file
    def analyze_only
      validate_input!
      analysis = analyze
      print_stats("ANALYSIS", analysis)
      analysis
    end

    private

    # ============================================
    # Validation
    # ============================================

    def validate_input!
      unless File.exist?(@input)
        raise Error, "Input file does not exist: #{@input}"
      end

      unless File.size(@input) > 0
        raise Error, "Input file is empty: #{@input}"
      end
    end

    # ============================================
    # Analysis (Pass 1)
    # ============================================

    def analyze
      command = [
        Suno.config.ffmpeg_path,
        "-hide_banner",
        "-i", @input,
        "-af", "loudnorm=print_format=json",
        "-f", "null",
        "-"
      ]

      output = run_command(command)

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
    rescue JSON::ParserError
      default_analysis
    end

    # ============================================
    # Duration Probe (for correct fade-out)
    # ============================================

    def probe_duration
      command = [
        Suno.config.ffmpeg_path,
        "-hide_banner",
        "-i", @input,
        "-f", "null",
        "-"
      ]

      output = run_command(command)

      # Look for "Duration: HH:MM:SS.ms"
      match = output.match(/Duration:\s*(\d+):(\d+):(\d+\.\d+)/)
      return 180.0 unless match # fallback 3 minutes

      hours = match[1].to_i
      minutes = match[2].to_i
      seconds = match[3].to_f

      (hours * 3600) + (minutes * 60) + seconds
    end

    # ============================================
    # Normalization (Pass 2)
    # ============================================

    def apply_normalization(analysis, target_lufs, true_peak, lra, fade_in, fade_out, duration)
      fade_out_start = [duration - fade_out, 0].max

      filter = [
        "loudnorm=I=#{target_lufs}:TP=#{true_peak}:LRA=#{lra}",
        "measured_I=#{analysis[:input_i]}",
        "measured_TP=#{analysis[:input_tp]}",
        "measured_LRA=#{analysis[:input_lra]}",
        "measured_thresh=#{analysis[:input_thresh]}",
        "offset=#{analysis[:offset]}",
        "linear=true",
        "afade=t=in:st=0:d=#{fade_in}",
        "afade=t=out:st=#{fade_out_start}:d=#{fade_out}"
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

    # ============================================
    # Helpers
    # ============================================

    def run_command(command)
      escaped = command.map { |c| Shellwords.escape(c) }.join(" ")
      `#{escaped} 2>&1`
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
