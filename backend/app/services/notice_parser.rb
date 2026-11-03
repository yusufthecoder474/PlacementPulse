# Deterministic, rule-based parser for pasted placement notices.
#
# Pure Ruby: no database access, no LLM, no external service. It uses
# regular expressions, keyword matching, and normalisation rules only.
#
# Contract: NoticeParser.call(source_text) returns
#   { parsed: { company:, category:, drive_date:, eligible_branches:,
#               minimum_cgpa:, minimum_class_x_percentage:,
#               minimum_class_xii_percentage:, arrears_rule:, ctc:, stipend:,
#               registration_deadline:, registration_url:, location: },
#     uncertainties: [{ field:, message: }, ...] }
#
# Rules that matter for correctness:
# - A missing field is NEVER treated as "no requirement". It becomes nil
#   plus an uncertainty entry, and publication is blocked until a
#   coordinator either fills it in or explicitly confirms it as unrestricted.
# - A deadline with no timezone is interpreted as Asia/Kolkata (the
#   application's configured time zone) and stored in UTC by Active Record.
# - A deadline date with no time is treated as 23:59 on that date, so a
#   "last date: 12 Jan 2027" notice does not expire at midnight.
class NoticeParser
  # Canonical branch codes and the spellings/abbreviations seen in notices.
  BRANCH_SYNONYMS = {
    "CSE" => "CSE",
    "CS" => "CSE",
    "COMPUTER SCIENCE" => "CSE",
    "COMPUTER SCIENCE AND ENGINEERING" => "CSE",
    "ECE" => "ECE",
    "ELECTRONICS AND COMMUNICATION" => "ECE",
    "ELECTRONICS AND COMMUNICATION ENGINEERING" => "ECE",
    "EEE" => "EEE",
    "ELECTRICAL AND ELECTRONICS" => "EEE",
    "ELECTRICAL AND ELECTRONICS ENGINEERING" => "EEE",
    "MECH" => "MECH",
    "MECHANICAL" => "MECH",
    "MECHANICAL ENGINEERING" => "MECH",
    "CIVIL" => "CIVIL",
    "CIVIL ENGINEERING" => "CIVIL",
    "IT" => "IT",
    "INFORMATION TECHNOLOGY" => "IT",
    "AI" => "AI",
    "ARTIFICIAL INTELLIGENCE" => "AI",
    "DS" => "DS",
    "DATA SCIENCE" => "DS"
  }.freeze

  ALL_BRANCHES = %w[CSE ECE EEE MECH CIVIL IT AI DS].freeze

  FIELDS = %w[
    company category drive_date eligible_branches
    minimum_cgpa minimum_class_x_percentage minimum_class_xii_percentage
    arrears_rule ctc stipend registration_deadline registration_url location
  ].freeze

  MONTHS = {
    "jan" => 1, "january" => 1, "feb" => 2, "february" => 2,
    "mar" => 3, "march" => 3, "apr" => 4, "april" => 4,
    "may" => 5, "jun" => 6, "june" => 6, "jul" => 7, "july" => 7,
    "aug" => 8, "august" => 8, "sep" => 9, "sept" => 9, "september" => 9,
    "oct" => 10, "october" => 10, "nov" => 11, "november" => 11,
    "dec" => 12, "december" => 12
  }.freeze

  def self.call(source_text)
    new(source_text).call
  end

  def initialize(source_text)
    @text = source_text.to_s
    @lines = @text.lines.map(&:strip).reject(&:empty?)
    @uncertainties = []
  end

  def call
    parsed = {
      company: extract_company,
      category: extract_category,
      drive_date: extract_drive_date,
      eligible_branches: extract_branches,
      minimum_cgpa: extract_cgpa,
      minimum_class_x_percentage: extract_percentage(:x),
      minimum_class_xii_percentage: extract_percentage(:xii),
      arrears_rule: extract_arrears,
      ctc: extract_ctc,
      stipend: extract_stipend,
      registration_deadline: extract_deadline,
      registration_url: extract_url,
      location: extract_location
    }

    FIELDS.each do |field|
      value = parsed[field.to_sym]
      next unless value.nil? || (value.respond_to?(:empty?) && value.empty?)
      next if @uncertainties.any? { |u| u[:field] == field }

      @uncertainties << { field: field, message: "#{field.humanize} could not be extracted from the notice text." }
    end

    { parsed: parsed, uncertainties: @uncertainties }
  end

  private

  # --- generic helpers -------------------------------------------------

  def labelled_value(labels)
    pattern = /\A(?:#{labels})\s*[:\-]\s*(.+)\z/i
    @lines.each do |line|
      match = line.match(pattern)
      return match[1].strip.sub(/[.\s]+\z/, "") if match
    end
    nil
  end

  def parse_date_in(text)
    return nil if text.nil?

    if (m = text.match(/(\d{4})-(\d{2})-(\d{2})/))
      date = safe_date(m[1].to_i, m[2].to_i, m[3].to_i)
      return date if date
    end

    month_names = MONTHS.keys.join("|")
    if (m = text.match(/(\d{1,2})\s+(#{month_names})\s+(\d{4})/i))
      date = safe_date(m[3].to_i, MONTHS[m[2].downcase], m[1].to_i)
      return date if date
    end
    if (m = text.match(/(#{month_names})\s+(\d{1,2}),?\s+(\d{4})/i))
      date = safe_date(m[3].to_i, MONTHS[m[1].downcase], m[2].to_i)
      return date if date
    end
    # Indian notices most often write day first: 12/01/2027 is 12 January.
    if (m = text.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})/))
      date = safe_date(m[3].to_i, m[2].to_i, m[1].to_i)
      return date if date
    end
    nil
  end

  def safe_date(year, month, day)
    Date.new(year, month, day)
  rescue ArgumentError, TypeError
    nil
  end

  def clean_number(raw)
    num = raw.to_s.delete(",")
    num.sub(/\.0+\z/, "")
  end

  def add_uncertainty(field, message)
    @uncertainties << { field: field, message: message } unless @uncertainties.any? { |u| u[:field] == field }
  end

  # --- individual fields ----------------------------------------------

  def extract_company
    value = labelled_value("company|organisation|organization")
    return value if value.present?

    @lines.each do |line|
      match = line.match(/\A([A-Z][\w&.\- ]+?)\s+(?:is hiring|invites|is conducting|announces)\b/i)
      return match[1].strip if match
    end

    first = @lines.first
    if first && first.length <= 80 && first !~ /placement|drive|eligib|registr|notice|dear|hello|greetings/i && first !~ /:/
      return first
    end
    nil
  end

  def extract_category
    labelled_value("category|role|designation|position|job\\s*role") ||
      begin
        match = @text.match(/for the (?:role|position) of ([^\n,.]+)/i)
        match && match[1].strip
      end
  end

  def extract_drive_date
    labelled = labelled_value("drive\\s*date|date\\s+of\\s+drive|drive\\s+on")
    date = parse_date_in(labelled) if labelled
    return date if date

    @lines.each do |line|
      next unless line =~ /drive/i

      date = parse_date_in(line)
      return date if date
    end
    nil
  end

  def extract_branches
    line = @lines.find { |l| l =~ /(?:eligible\s+)?branch(?:es)?\s*(?:eligible)?\s*[:\-]/i }
    value = line&.sub(/\A.*[:\-]\s*/, "")
    return ALL_BRANCHES.dup if value.nil? && @text =~ /all branches/i
    return ALL_BRANCHES.dup if value =~ /\ball\b/i

    return [] if value.nil?

    branches = []
    unknowns = []
    # Split on commas/semicolons first. Only split a token on "and" when the
    # whole token is not itself a known branch name — otherwise
    # "Computer Science and Engineering" would be torn apart.
    value.split(/[,;]/).each do |comma_token|
      token = comma_token.strip.upcase.gsub(/[^A-Z ]/, "").strip
      parts = BRANCH_SYNONYMS.key?(token) ? [token] : token.split(/\band\b/i).map(&:strip)
      parts.each do |part|
        next if part.empty? || part == "BTECH" || part == "B TECH"

        canonical = BRANCH_SYNONYMS[part]
        if canonical
          branches << canonical unless branches.include?(canonical)
        else
          unknowns << part
        end
      end
    end
    if unknowns.any?
      add_uncertainty("eligible_branches",
                      "Unknown branch abbreviation(s): #{unknowns.uniq.join(', ')}. Please confirm the branches.")
    end
    branches
  end

  def extract_cgpa
    values = []
    @text.scan(/(?:minimum\s+)?cgpa[^0-9]{0,20}?(\d+(?:\.\d+)?)/i) { |m| values << m[0].to_f }
    @text.scan(/(\d+(?:\.\d+)?)\s*cgpa/i) { |m| values << m[0].to_f }
    values = values.select { |v| v >= 0 && v <= 10 }.uniq
    if values.size > 1
      add_uncertainty("minimum_cgpa", "Multiple CGPA values appear in the notice (#{values.join(', ')}). Please confirm the minimum CGPA.")
    end
    values.first
  end

  # Collects the percentage for one school level across all lines.
  def extract_percentage(level)
    markers = level == :x ? [/class\s+x\b/i, /10th/i, /\bssc\b/i] : [/class\s+xii\b/i, /12th/i, /\bhsc\b/i]
    values = []

    @lines.each do |line|
      x_mentioned = line =~ /class\s+x\b/i || line =~ /10th/i || line =~ /\bssc\b/i
      xii_mentioned = line =~ /class\s+xii\b/i || line =~ /12th/i || line =~ /\bhsc\b/i
      percents = line.scan(/(\d+(?:\.\d+)?)\s*%/).flatten.map(&:to_f)
      # "10th and 12th: 75%" (or the reverse) states one value for both levels.
      if x_mentioned && xii_mentioned && percents.size == 1
        values << percents.first
        next
      end
      next unless markers.any? { |marker| line =~ marker }

      # Level-specific patterns: a line stating both levels with two values
      # ("10th: 75%, 12th: 70%") must not let the 10th value leak into XII.
      if level == :x
        forward = line.match(/(?:class\s+x\b|10th|\bssc\b)[^0-9%]{0,40}?(\d+(?:\.\d+)?)\s*%/i)
        reverse = line.match(/(\d+(?:\.\d+)?)\s*%\s*(?:in\s+)?(?:class\s+x\b|10th|\bssc\b)/i)
      else
        forward = line.match(/(?:class\s+xii\b|12th|\bhsc\b)[^0-9%]{0,40}?(\d+(?:\.\d+)?)\s*%/i)
        reverse = line.match(/(\d+(?:\.\d+)?)\s*%\s*(?:in\s+)?(?:class\s+xii\b|12th|\bhsc\b)/i)
      end
      values << (forward ? forward[1].to_f : reverse[1].to_f) if forward || reverse
    end

    values = values.select { |v| v >= 0 && v <= 100 }.uniq
    field = level == :x ? "minimum_class_x_percentage" : "minimum_class_xii_percentage"
    if values.size > 1
      add_uncertainty(field,
                      "Different #{level == :x ? 'Class X' : 'Class XII'} percentages appear for different courses (#{values.join(', ')}). Please confirm the minimum.")
    end
    values.first
  end

  def extract_arrears
    down = @text.downcase
    return "no_standing_arrears" if down =~ /no standing arrears|no active arrears|no backlogs|zero backlogs|no active backlogs/
    return "standing_arrears_allowed" if down =~ /standing arrears allowed|arrears allowed|backlogs allowed|backlogs permitted|arrears permitted/

    if down.include?("arrear") || down.include?("backlog")
      add_uncertainty("arrears_rule", "The arrears wording in the notice is unclear. Please confirm the arrears rule.")
    end
    nil
  end

  def extract_ctc
    match = @text.match(/(?:ctc|package|salary)\s*[:\-]?\s*₹?\s*(\d+(?:\.\d+)?)\s*(?:lpa|lakhs?|l\.p\.a\.)?/i) ||
            @text.match(/(\d+(?:\.\d+)?)\s*lpa/i)
    return nil unless match

    "#{clean_number(match[1])} LPA"
  end

  def extract_stipend
    match = @text.match(/(?:stipend)\s*[:\-]?\s*₹?\s*([\d,]+(?:\.\d+)?)\s*(?:\/\s*month|per\s+month)?/i)
    match ||= @text.match(/₹\s*([\d,]+)\s*\/\s*month/i) if @text =~ /intern|stipend/i
    return nil unless match

    # Keep the thousands separator: "₹30,000/month", not "₹30000/month".
    "₹#{match[1].delete(' ')}/month"
  end

  def extract_deadline
    candidate_lines = @lines.select do |line|
      line =~ /registr/i && line =~ /deadline|last date|closes|closing/i
    end
    candidate_lines = @lines.select { |line| line =~ /deadline|last date/i } if candidate_lines.empty?

    dates = candidate_lines.filter_map { |line| parse_date_in(line) }.uniq
    if dates.size > 1
      add_uncertainty("registration_deadline",
                      "Multiple distinct deadline dates appear in the notice (#{dates.map(&:to_s).join(', ')}). Please confirm the registration deadline.")
    end
    return nil if dates.empty?

    line = candidate_lines.find { |l| parse_date_in(l) == dates.first }
    date = dates.first
    hour, minute = extract_time(line) || [23, 59]
    # Time.zone is Asia/Kolkata (see config/application.rb). A date with no
    # timezone in the notice is therefore read as Kolkata time.
    Time.zone.local(date.year, date.month, date.day, hour, minute)
  end

  def extract_time(line)
    return nil if line.nil?

    if (m = line.match(/(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m\.?/i))
      hour = m[1].to_i
      hour += 12 if m[3].downcase == "p" && hour < 12
      hour = 0 if m[3].downcase == "a" && hour == 12
      return [hour, (m[2] || "0").to_i]
    end
    if (m = line.match(/(\d{1,2}):(\d{2})/))
      return [m[1].to_i, m[2].to_i] if m[1].to_i <= 23
    end
    nil
  end

  def extract_url
    match = @text.match(%r{https?://[^\s,;\])]+})
    return match[0].sub(/[.,]+\z/, "") if match

    www = @text.match(/www\.[^\s,;\])]+/)
    return "https://#{www[0].sub(/[.,]+\z/, '')}" if www

    if @text =~ /registr/i && @text =~ /link|url|website/i
      add_uncertainty("registration_url", "A registration link is mentioned but no usable http(s) URL was found.")
    end
    nil
  end

  def extract_location
    labelled_value("job\\s*location|work\\s*location|location|venue")
  end
end
