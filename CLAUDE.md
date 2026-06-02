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

2. **Downloaders** — 11 subclasses of `Downloader`, each fetching from a specific Swiss data source. 10 live in `lib/oddb2xml/downloader.rb`; the FHIR downloader lives in `lib/oddb2xml/fhir_support.rb`. Files cached in `./downloads/`.

3. **Extractors** (`lib/oddb2xml/extractor.rb`) — Matching extractor classes that parse downloaded files into Ruby hashes. Formats include XML (nokogiri/sax-machine), XLSX (rubyXL), CSV, and fixed-width text. Refdata uses the new SwissReg XML format from a zip download (`files.refdata.ch`).

4. **Builder** (`lib/oddb2xml/builder.rb`) — The largest file (~1900 lines). Merges extracted data and generates output XML/DAT files. Methods follow `prepare_*` (data assembly) and `build_*` (output generation) naming.

5. **Calc** (`lib/oddb2xml/calc.rb`) — Composition calculation logic, works with `parslet_compositions.rb` and `compositions_syntax.rb` (Parslet-based PEG parser for drug composition strings).

6. **Compressor** (`lib/oddb2xml/compressor.rb`) — Optional ZIP/TAR.GZ output compression.

7. **FHIR support** (`lib/oddb2xml/fhir_support.rb`) — Self-contained module providing `FhirDownloader` and FHIR NDJSON parsing. Activated via `--fhir` (or `--fhir-url=<URL>`). Downloads per-language NDJSON files (`foph-sl-export-latest-{de,fr,it}.ndjson`) from `epl.bag.admin.ch` to populate French and Italian product names/descriptions. Maps legal status codes `756005022007` and `756005022008` to Swissmedic category D. Reads the BAG **Indikationscode** (`XXXXX.NN`) from the explicit `indicationCode` extension on each `RegulatedAuthorization.indication[].extension[regulatedAuthorization-limitation]` (BAG SL FHIR export >= v2.0.5; handled from 3.0.10). The BAG changelog states the limitation code (`ClinicalUseDefinition.id`) and the indication code are **independent** fields, so the older derivation — combining each indication CUD's `.NN` id-suffix with the reimbursement RA's `FOPHDossierNumber` — is kept only as a fallback for feeds lacking the extension. Exposed as `item[:indication_codes]` and per-package `:indication_codes` (each entry a `{code:, cud_id:, text:}` hash, where `cud_id` is the `limitationIndication` CUD reference used to resolve the text). From 3.0.7 onwards, `Builder#build_product` emits one `<INDICATION_CODE code="XXXXX.NN" cud_id="DRUG.NN">limitation text</INDICATION_CODE>` child per indication on every `<PRD>` in `oddb_product.xml`; live feed numbers: 539 products / 1,293 codes / 100 % with non-empty indication text. Mandatory on prescriptions/invoices for SL price-model drugs from 2026-07-01 — see issue [#113](https://github.com/zdavatz/oddb2xml/issues/113). **Limitation texts** (3.0.8 onwards): the `regulatedAuthorization-limitation` extension has no inline `limitationText` in the live BAG feed — it carries a `limitationIndication` reference to a `ClinicalUseDefinition` whose `indication.diseaseSymptomProcedure.concept.text` is the actual text. The parser stores the ref as `cud_ref` on each Limitation, `Bundle#cud_text_by_id` resolves DE, and `merge_language` propagates FR/IT from the per-language NDJSON files via the same CUD id. Coverage on the live feed jumped from 0 / 9'108 to 9'108 / 9'108 (issue [#116](https://github.com/zdavatz/oddb2xml/issues/116)). **Limitation code / LIMNAMEBAG** (3.0.12 onwards): FHIR has no native BAG limitation code (LIMCD), so `create_limitations_for_package` sets `LimitationCode = cud_ref` (the `limitationIndication` CUD id) instead of `""`. Without this, every FHIR limitation shared an empty `:code`; `Builder#build_artikelstamm` groups its `<LIMITATIONS>` section by code, so all of them collapsed into a single `<LIMITATION>` with an empty `<LIMNAMEBAG>` and only one text survived. Using the CUD id as the key makes each distinct limitation emit and be referenced from its `<PRODUCT>`. The downstream `bin/check_artikelstamm` (`semantic_check.rb`) also crashed on the lone-element output because Ox `:hash_no_attrs` collapses a one-child section into a Hash (and an empty one into nil) — `SemanticCheckXML#get_items` now normalises every section to an Array.

8. **Refdata cleanup** (`lib/oddb2xml/refdata_cleanup.rb`) — Compensates for known data-quality issues in upstream Refdata.Articles.xml before they reach the output. Each fix is guarded by a Swissmedic-side heuristic (e.g. comma in `substance_swissmedic` to distinguish mono products from real combinations). Currently fixes (a) the doubled-dose template bug (`X mg / X mg / Stk`, `fix_double_dose`, guarded by `single_substance?`); (b) the spelled-out German galenic form `Retardtabletten` → house-style abbreviation `Ret Tabl` (`normalize_galenic_form` / `GALENIC_NORMALISATIONS`, issue #112 case #13, e.g. RINVOQ — a narrow word-boundary substitution that leaves legitimate brand suffixes like `TRAMAL retard` and Mepha's `Lactab` untouched); and (c) dose info Refdata dropped from `<FullName>`, sourced from the Swissmedic composition string `pack[:composition_swissmedic]` — `fix_missing_combo_dose` (#6, appends a combination's 2nd component strength), `fix_missing_dose` (#4, inserts a mono product's missing strength before the pack count), `fix_missing_volume` (#7, appends an injectable's per-pen volume); and (d) 50-char-truncation repairs — `fix_truncated_metoject` (#1, rebuilds METOJECT Autoinjektor names from the intact `<brand> Autoinjektor <dose>/<vol>` prefix + Swissmedic `size`, localised DE/FR/IT) and `fix_truncated_volume_unit` (#3, restores the cut `ml` of the VERACTIV Vitamin D3 drops). The (c) and (d) fixes are scoped to explicit IKSNR allow-lists (`COMBO_DOSE_IKSNR`/`MISSING_DOSE_IKSNR`/`MISSING_VOLUME_IKSNR`/`METOJECT_IKSNR`/`VERACTIV_VITD3_IKSNR`): a dry run proved a blanket heuristic mis-fires on hundreds of legitimate names (sodium counter-ion doses, strength-less phyto/powder products, concentration names like `CIMZIA 200 mg/ml`), so only catalogued registrations are touched — add an IKSNR to grow coverage. Called from `Builder#apply_refdata_description_cleanups!` at the start of `prepare_articles`. See GitHub issue #112 for the catalogue.

9. **Chapter-70 hack** (`lib/oddb2xml/chapter_70_hack.rb`) — Legacy scraper for the SL "Komplementärarzneimittel" products (homeopathic/anthroposophic/phytotherapeutic), called only from `Builder#build_artikelstamm`. **Deprecated / non-FHIR only (3.0.11 onwards):** the source page `varia_De.htm` was rebuilt as a JavaScript SPA with no static data table, so the scraper now returns nothing there. These products + limitations now come through the FHIR feed (SL classification `20. KOMPLEMENTÄRARZNEIMITTEL`, 221 products on the live DE feed with real GTINs and limitation texts), so `build_artikelstamm` **skips the scraper entirely when `@options[:fhir]`** (the default for `--artikelstamm` since 3.0.9). In `--no-fhir` mode the scraper degrades gracefully (skips non-row/`<script>` nodes and empty tables, warns, returns `[]`) instead of raising `NoMethodError`. See GitHub issue #118.

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
- Current development: Ruby 3.3.6 (`.ruby-version`)
