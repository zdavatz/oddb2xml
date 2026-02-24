# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

oddb2xml is a Ruby gem that downloads Swiss pharmaceutical data from 10+ sources (Swissmedic, BAG, Refdata, ZurRose, EPha, etc.), parses multiple formats (XML, XLSX, CSV, SOAP, fixed-width DAT), merges/deduplicates them, and generates standardized XML/DAT output files for healthcare systems. It also supports the Elexis EHR Artikelstamm format.

## Common Commands

```bash
# Install dependencies
bundle install

# Run full test suite
bundle exec rake spec

# Run a single test file
bundle exec rspec spec/builder_spec.rb

# Run a single test by line number
bundle exec rspec spec/builder_spec.rb:42

# Lint with StandardRB
bundle exec standardrb

# Auto-fix lint issues
bundle exec standardrb --fix

# Build the gem
bundle exec rake build
```

## Architecture

The system follows a **download → extract → build → compress** pipeline:

1. **CLI** (`lib/oddb2xml/cli.rb`) — Entry point. Parses options via Optimist (`options.rb`), orchestrates the pipeline, manages multi-threaded downloads.

2. **Downloaders** (`lib/oddb2xml/downloader.rb`) — 11 subclasses of `Downloader`, each fetching from a specific Swiss data source. Files cached in `./downloads/`.

3. **Extractors** (`lib/oddb2xml/extractor.rb`) — Matching extractor classes that parse downloaded files into Ruby hashes. Formats include XML (nokogiri/sax-machine), XLSX (rubyXL), SOAP (savon), CSV, and fixed-width text.

4. **Builder** (`lib/oddb2xml/builder.rb`) — The largest file (~1900 lines). Merges extracted data and generates output XML/DAT files. Methods follow `prepare_*` (data assembly) and `build_*` (output generation) naming.

5. **Calc** (`lib/oddb2xml/calc.rb`) — Composition calculation logic, works with `parslet_compositions.rb` and `compositions_syntax.rb` (Parslet-based PEG parser for drug composition strings).

6. **Compressor** (`lib/oddb2xml/compressor.rb`) — Optional ZIP/TAR.GZ output compression.

### Key data identifiers
- **GTIN/EAN13**: Primary article identifier (13-digit barcode)
- **Pharmacode**: Swiss pharmacy code
- **IKSNR**: Swissmedic registration number (5-digit)
- **Swissmedic sequence/pack numbers**: Combined with IKSNR to form full identifiers

### Static data overrides
YAML files in `data/` provide manual overrides and mappings: `article_overrides.yaml`, `product_overrides.yaml`, `gtin2ignore.yaml`, `gal_forms.yaml`, `gal_groups.yaml`.

## Testing

- Framework: RSpec with flexmock (mocking), webmock + VCR (HTTP recording/playback)
- Test fixtures: `spec/data/` (sample files), `spec/fixtures/vcr_cassettes/` (recorded HTTP responses)
- `spec/spec_helper.rb` defines test constants (GTINs) and configures VCR to avoid real HTTP calls during tests
- CI runs on Ruby 3.0, 3.1, 3.2

## Ruby Version

- Minimum: Ruby >= 2.5.0 (gemspec)
- Current development: Ruby 3.2.0 (`.ruby-version`)
