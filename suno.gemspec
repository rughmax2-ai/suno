# frozen_string_literal: true

require_relative "lib/suno/version"

Gem::Specification.new do |spec|
  spec.name          = "suno"
  spec.version       = Suno::VERSION
  spec.authors       = ["rughmax2-ai"]
  spec.email         = [""]

  spec.summary       = "Professional AI music workflow gem"
  spec.description   = "Turns AI-generated music into broadcast-ready assets with loudness normalization, artistic cover art, multi-provider support, and full provenance."
  spec.homepage      = "https://github.com/rughmax2-ai/suno"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.\w)})
    end
  end

  spec.bindir        = "bin"
  spec.executables   = ["suno"]
  spec.require_paths = ["lib"]

  # === Minimal & Explicit Dependencies ===
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "streamio-ffmpeg", "~> 3.0"
  spec.add_dependency "mini_magick", "~> 5.0"
  spec.add_dependency "sqlite3", "~> 1.7"
  spec.add_dependency "pastel", "~> 0.8"

  # Development dependencies will be added later as needed
  # Keep runtime dependencies as lean as possible
end
