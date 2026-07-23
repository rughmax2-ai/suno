# Suno

**Professional AI Music Workflow Toolkit**

A carefully engineered Ruby gem that turns AI-generated music into **broadcast-ready, reproducible creative assets**.

> From creative intent → high-quality audio + artistic cover + proper metadata + loudness normalization.

---

## Philosophy

Most AI music tools dump raw files.  
This gem produces **finished assets**.

- Consistent loudness (-14 LUFS)
- Embedded provenance (prompt + seed + version)
- Artistic cover art (18+ styles with automatic detection)
- Multi-provider support (Stable Audio + MusicGen)
- Clean, professional Ruby DSL

---

## Current Status

This project is under active, careful development.  
The architecture prioritizes **security, reliability, and clean design** over speed of feature delivery.

---

## Installation

```bash
gem install suno
```

Or add to your Gemfile:

```ruby
gem "suno"
```

---

## Quick Example

```ruby
require "suno"

song = Suno::Song.build do
  title "Neon Rain"
  concept "Cyberpunk night drive"
  style "synthwave"

  post_process do
    normalize loudness: -14.0
    tag do
      artist "Your Project"
      album "Vol. 1"
    end
  end
end

result = Suno.generate(song)
puts result[:local_path]
```

---

## Security Notes

- Never commit API keys
- All secrets should be loaded from environment variables
- The gem never stores credentials in the repository
- A strong `.gitignore` is enforced from day one

---

## Development Principles

1. **Security first**
2. **No stub code in core paths**
3. **Explicit error handling**
4. **Minimal dependencies**
5. **Clean architecture over feature bloat**

---

## License

MIT

---

Built with care for creators who want professional results.
