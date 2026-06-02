module Oddb2xml
  # Compensates for known data-quality issues in upstream Refdata.Articles.xml
  # before they reach the generated output. Each fix is opt-in and guarded by
  # a heuristic against Swissmedic data so we never alter genuine combination
  # products. See GitHub issue #112 for the catalogue of upstream problems.
  module RefdataCleanup
    DOSE_TOKEN = /\d+(?:[.,]\d+)?\s*(?:mg|µg|mcg|g|ml|UI|U\.I\.|IE|%)/i
    # Matches "<dose> / <same dose> /" – the templating bug where Refdata
    # repeats the strength once. The backreference \1 only matches when the
    # exact same dose string appears twice, which keeps real combos
    # (e.g. PHESGO 600 mg / 600 mg / 10 ml) safe – those are caught by the
    # single_substance? guard, but the literal-match also acts as a backstop.
    DOUBLE_DOSE_RE = /(#{DOSE_TOKEN})\s*\/\s*\1\s*\/\s*/

    # A Swissmedic compositions cell like "mirtazapinum" indicates a mono
    # product; "atovaquonum, proguanili hydrochloridum" or
    # "pertuzumabum, trastuzumabum" indicates a real combination.
    def self.single_substance?(swissmedic_substance)
      return false if swissmedic_substance.nil?
      str = swissmedic_substance.to_s.strip
      return false if str.empty?
      !str.include?(",")
    end

    # Removes the duplicated dose token in mono products. Returns the
    # cleaned description, or the original string if no change applies.
    def self.fix_double_dose(desc, swissmedic_substance)
      return desc if desc.nil? || desc.empty?
      return desc unless DOUBLE_DOSE_RE.match?(desc)
      return desc unless single_substance?(swissmedic_substance)
      desc.sub(DOUBLE_DOSE_RE, '\1 / ')
    end

    # Case #13 (issue #112): a handful of products spell the galenic form out
    # in full ("RINVOQ Retardtabletten 30 mg 28 Stk") while the Refdata house
    # style abbreviates it everywhere else ("Ret Tabl", 940 other DE names).
    # Normalise the spelled-out form to the abbreviation so the outliers match
    # the convention. The keys are German-only words (FR/IT use "comprimé …" /
    # "compresse …"), so applying this to FR/IT descriptions is a safe no-op.
    GALENIC_NORMALISATIONS = {
      /\bRetardtabletten\b/ => "Ret Tabl"
    }.freeze

    # Normalises spelled-out German galenic forms to the Refdata house-style
    # abbreviation. Returns the cleaned description, or the original string if
    # no rule applies.
    def self.normalize_galenic_form(desc)
      return desc if desc.nil? || desc.empty?
      GALENIC_NORMALISATIONS.reduce(desc) { |result, (re, repl)| result.gsub(re, repl) }
    end

    # The following three fixes reconstruct dose information that Refdata
    # dropped from <FullName>, sourcing the authoritative values from the
    # Swissmedic "Zugelassene Packungen" composition string (already loaded as
    # pack[:composition_swissmedic], keyed by the same SwissmedicNo8). See
    # issue #112 cases #4 (missing strength), #6 (missing 2nd combo component)
    # and #7 (missing injection volume).
    #
    # Each fix is scoped to an explicit allow-list of Swissmedic registration
    # numbers (IKSNR, the first 5 digits of the no8). A blanket heuristic is
    # NOT safe: a dry run over the full Refdata feed mis-fired on hundreds of
    # legitimate names — combination detection grabbed sodium counter-ion doses
    # ("KEPPRA … / 2.8 mg"), the missing-strength rule fired on strength-less
    # phyto/powder products ("IMPORTAL Pulver"), and the volume rule corrupted
    # concentration names ("CIMZIA 200 mg/ml"). Restricting to the catalogued
    # registrations keeps the Swissmedic-derived value while touching only the
    # known-bad products. Add an IKSNR here once a new case is confirmed.
    COMBO_DOSE_IKSNR = %w[65280].freeze      # #6 ATOVAQUON PLUS Spirig HC
    MISSING_DOSE_IKSNR = %w[62568].freeze    # #4 CETIRIZIN Spirig HC
    MISSING_VOLUME_IKSNR = %w[69696].freeze  # #7 MOUNJARO KwikPen

    def self.iksnr_of(no8)
      no8.to_s[0, 5]
    end

    # Builds a whitespace-tolerant matcher for a normalised dose value like
    # "250 mg" so it also matches "250mg" in a description.
    def self.dose_regex(dose)
      m = dose.to_s.match(/\A([\d.,]+)\s*(.+?)\s*\z/)
      return /#{Regexp.escape(dose.to_s)}/i unless m
      /(?<![\d.,])#{Regexp.escape(m[1])}\s*#{Regexp.escape(m[2])}/i
    end

    # Returns the dose token that belongs to a named active substance in the
    # Swissmedic composition, normalised to "<number> <unit>" (e.g.
    # dose_for_substance(comp, "atovaquonum") => "250 mg"). Matches within the
    # comma-delimited segment that names the substance so excipient doses are
    # never picked up. Returns nil if absent.
    def self.dose_for_substance(composition, substance)
      return nil if composition.nil? || substance.nil?
      key = substance.to_s.strip[/\A[A-Za-zÀ-ÿ]+/]
      return nil if key.nil? || key.empty?
      composition.split(",").each do |segment|
        next unless /\b#{Regexp.escape(key)}/i.match?(segment)
        m = segment.match(DOSE_TOKEN)
        next unless m
        parts = m[0].match(/\A([\d.,]+)\s*(.+?)\s*\z/)
        return parts ? "#{parts[1]} #{parts[2]}" : m[0].strip
      end
      nil
    end

    # Case #6: a real combination product whose Refdata description carries
    # only the first component's strength (e.g. "ATOVAQUON PLUS … 250 mg …").
    # Appends the second active's strength from Swissmedic, producing
    # "… 250 mg / 100 mg …". No-op for mono products, 3+ component combos, or
    # when the second strength is already present.
    def self.fix_missing_combo_dose(desc, swissmedic_substance, composition, no8)
      return desc if desc.nil? || desc.empty?
      return desc unless COMBO_DOSE_IKSNR.include?(iksnr_of(no8))
      return desc if single_substance?(swissmedic_substance)
      subs = swissmedic_substance.to_s.split(",").map(&:strip)
      return desc unless subs.size == 2
      d1 = dose_for_substance(composition, subs[0])
      d2 = dose_for_substance(composition, subs[1])
      return desc unless d1 && d2
      return desc unless dose_regex(d1).match?(desc)
      return desc if dose_regex(d2).match?(desc)
      desc.sub(dose_regex(d1)) { |hit| "#{hit} / #{d2}" }
    end

    # Case #4: a mono product whose Refdata description carries NO strength at
    # all (e.g. "CETIRIZIN Spirig HC Filmtabl 10 Stk"). Inserts the single
    # active's strength from Swissmedic before the trailing "<count> <unit>"
    # group → "CETIRIZIN Spirig HC Filmtabl 10 mg 10 Stk". No-op when a
    # strength is already present or no trailing pack count exists.
    def self.fix_missing_dose(desc, swissmedic_substance, composition, no8)
      return desc if desc.nil? || desc.empty?
      return desc unless MISSING_DOSE_IKSNR.include?(iksnr_of(no8))
      return desc unless single_substance?(swissmedic_substance)
      return desc if DOSE_TOKEN.match?(desc)
      dose = dose_for_substance(composition, swissmedic_substance)
      return desc unless dose
      return desc unless /\s\d[\d.,']*\s+\S+\s*\z/.match?(desc)
      desc.sub(/(\s)(\d[\d.,']*\s+\S+\s*)\z/, "\\1#{dose} \\2")
    end

    # Case #7: an injectable pen/solution whose Refdata description gives the
    # strength but not the per-pen volume (e.g. "MOUNJARO KwikPen Inj Lös
    # 7.5 mg 1 Stk"). Appends "/<vol> ml" taken from the Swissmedic
    # composition ("… pro 0.6 ml …") → "… 7.5 mg/0.6 ml 1 Stk". Only fires for
    # injectable forms that have no volume anywhere in the name yet.
    def self.fix_missing_volume(desc, composition, no8)
      return desc if desc.nil? || desc.empty?
      return desc unless MISSING_VOLUME_IKSNR.include?(iksnr_of(no8))
      return desc unless /\b(?:Inj|Fertpen|Injektor|stylo|sol\b)/i.match?(desc)
      return desc if /\d\s*ml\b/i.match?(desc)
      vol = composition.to_s[/\bpro\s+([\d.,]+)\s*ml\b/i, 1]
      return desc unless vol
      m = desc.match(/\d+(?:[.,]\d+)?\s*mg/i)
      return desc unless m
      desc.sub(m[0], "#{m[0]}/#{vol} ml")
    end
  end
end
