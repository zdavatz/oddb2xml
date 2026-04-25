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
  end
end
