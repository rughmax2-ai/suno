# Suno

**Professional AI Music Workflow Toolkit**

A carefully engineered Ruby gem that transforms AI-generated music into **broadcast-ready, reproducible creative assets**.

> From creative intent → high-quality audio + artistic cover + proper metadata + professional loudness normalization.

---

## Why This Exists

Most AI music tools dump raw files into a downloads folder.  
**Suno** produces finished assets.

- Consistent loudness (-14 LUFS streaming standard)
- Two-pass loudness analysis with before/after reporting
- Multi-provider architecture (Stable Audio + MusicGen)
- Explicit fallback between providers
- Clean, expressive Ruby DSL
- Strong security posture from day one

---

## Current Architecture

```text
Suno.generate(...)
    → Client (multi-provider + fallback)
        → Provider (Stable Audio / MusicGen)
            → Downloader (safe local storage)
                → Normalizer (two-pass LUFS)
                    → Future: CoverArt + Tagging + Organization
```

---

## Installation

```bash
gem install suno
```

Or in your Gemfile:

```ruby
gem "suno"
```

---

## Quick Start

```ruby
require "suno"

Suno.configure do |c|
  c.storage_path = "~/Music/Suno"
  c.provider = :stable_audio
  c.fallback_provider = :musicgen
  c.target_lufs = -14.0
end

song = Suno::Song.build do
  title "Neon Rain"
  concept "Cyberpunk night drive through neon streets"
  style "synthwave"

  post_process do
    normalize loudness: -14.0
  end
end

result = Suno.generate(song)
puts result[:local_path]
```

---

## Core Components (Implemented)

| Component | Status | Description |
|---------|--------|-------------|
| `Song` DSL | ✅ | Clean creative interface |
| `Client` | ✅ | Multi-provider router with explicit fallback |
| `Downloader` | ✅ | Safe, clean local file handling |
| `Normalizer` | ✅ | Two-pass loudness normalization + stats |
| `Config` | ✅ | Secure configuration (no secrets in code) |
| CLI | ✅ | Minimal professional skeleton |

---

## Security Posture

- Strong `.gitignore` from the first commit
- No API keys stored in source
- Secrets must come from environment variables
- Explicit error classes instead of silent failures
- Minimal dependency surface

---

## Development Principles

1. **Security first**
2. **No stub code in core paths**
3. **Explicit error handling**
4. **Minimal dependencies**
5. **Clean architecture over feature bloat**
6. **Methodical, risk-reducing progress**

---

## Roadmap (Careful Order)

- [ ] Provider clients (`StableAudioClient`, `MusicGenClient`)
- [ ] Cover art generation + embedding
- [ ] ID3 tagging + provenance
- [ ] File organization
- [ ] Local gallery
- [ ] Full CLI expansion

---

## License

MIT

---

Built with care for creators who want professional results.
