# frozen_string_literal: true

module SiteSupport
  ROOT        = File.expand_path("../..", __dir__)
  POSTS_DIR   = File.join(ROOT, "_posts")
  CROSSPOSTS_DIR = File.join(ROOT, "crossposts")
  BASE_URL    = "https://49thit.com"

  module_function

  def slugify(text)
    text.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/-+/, "-").gsub(/\A-|-?\z/, "")
  end

  def normalize_plaintext(text)
    return "" if text.nil?

    replacements = {
      "\u2013" => "-",
      "\u2014" => "--",
      "\u2015" => "--",
      "\u2212" => "-",
      "\u2018" => "'",
      "\u2019" => "'",
      "\u201c" => '"',
      "\u201d" => '"',
      "\u2026" => "...",
      "\u00a0" => " "
    }

    normalized = text.dup
    replacements.each do |pattern, replacement|
      normalized.gsub!(pattern, replacement)
    end
    normalized
  end

  def append_ellipses(text)
    clean = text.to_s.strip
    return "" if clean.empty?
    clean = clean.sub(/\.*\z/, "")
    "#{clean}..."
  end

  def single_line_message(title, blurb, link = BASE_URL)
    title = title.to_s.strip
    return "" if title.empty?

    summary = blurb.to_s.gsub(/\s+/, " ").strip
    summary = title if summary.empty?
    message = "#{title} - #{summary}".strip
    link_part = link.to_s.strip

    return message if link_part.empty?
    message = message.sub(/\.*\z/, "")
    "#{message}... #{link_part}"
  end

  def ensure_trailing_newline(text)
    text.end_with?("\n") ? text : "#{text}\n"
  end
end
