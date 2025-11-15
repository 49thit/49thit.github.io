#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "date"
require "fileutils"
require "net/http"
require "json"
require "time"
require "uri"
require "securerandom"
require_relative "lib/site_support"

ROOT        = SiteSupport::ROOT
POSTS_DIR   = SiteSupport::POSTS_DIR
NEXT_GLOB   = File.join(POSTS_DIR, "*episodeNEXT*.md")
BODY_END    = "##"
API_KEY_PATH = File.join(ROOT, ".apikey-openai")
DEFAULT_TAGS = %w[alaska IT scifi].freeze
DEFAULT_IMAGE_PATH = "/assets/img/thumbnail.png"
BASE_URL = SiteSupport::BASE_URL
X_CHAR_LIMIT = 280
BLUESKY_CHAR_LIMIT = 300
LOG_DIR     = File.join(ROOT, "logs")
MAX_LOG_FILES = 12
LOG_TIME_FORMAT = "%Y-%m-%d-%H-%M-%S-%L"
MIN_EXTRA_TAGS = 3
AI_MODEL    = "gpt-4o-mini"
AI_TEMPERATURE = 0.3
AI_MAX_OUTPUT_TOKENS = 256
EPISODE_NEXT_PATH = File.join(ROOT, "_posts", "2024-01-01-episodeNEXT.md")
DEFAULT_NEXT_TEASER = "Stay tuned. Next time on 49thIT..."
OPENAI_URI = URI("https://api.openai.com/v1/responses")
ALASKA_TZ_NAME = "America/Anchorage"
DRAFTS_DIR = File.join(ROOT, "episode_drafts")
LEGACY_DRAFT_PATHS = [
  File.join(ROOT, "logs", "episode_drafts"),
  File.expand_path(File.join(__dir__, "logs", "episode_drafts"))
].uniq
TAG_JSON_SCHEMA = {
  name: "episode_tags",
  schema: {
    type: "object",
    properties: {
      tags: {
        type: "array",
        items: {
          type: "string",
          pattern: "^[a-z0-9-]{2,48}$"
        },
        minItems: MIN_EXTRA_TAGS,
        maxItems: MIN_EXTRA_TAGS
      }
    },
    required: ["tags"],
    additionalProperties: false
  }
}.freeze

def alaska_time
  previous = ENV["TZ"]
  ENV["TZ"] = ALASKA_TZ_NAME
  Time.now
ensure
  ENV["TZ"] = previous
end

def prompt(label, default: nil, required: false)
  loop do
    print("#{label}#{default ? " [#{default}]" : ""}: ")
    input = STDIN.gets&.strip
    exit 1 if input.nil?
    input = default if input.empty? && default
    return input unless required && (input.nil? || input.empty?)
    puts "This value is required."
  end
end

def prompt_multiline(label, terminator: BODY_END)
  puts "#{label} (finish with #{terminator.inspect} on its own line):"
  lines = []
  while (line = STDIN.gets)
    stripped = line.chomp
    break if stripped == terminator
    lines << stripped
  end
  lines.join("\n").strip
end

def prompt_yes_no(question, default: true)
  suffix = default ? "[Y/n]" : "[y/N]"
  loop do
    print("#{question} #{suffix} ")
    input = STDIN.gets
    exit 1 if input.nil?
    input = input.strip.downcase
    return default if input.empty?
    return true if %w[y yes].include?(input)
    return false if %w[n no].include?(input)
    puts "Please answer y or n."
  end
end

def prompt_body_input(label: "Paste the full Markdown body", terminator: BODY_END)
  loop do
    body = prompt_multiline(label, terminator: terminator)
    if body.empty?
      puts "Body cannot be empty."
      next
    end
    return ensure_markdown_paragraphs(body)
  end
end

def ensure_markdown_paragraphs(text)
  normalized = text.gsub("\r\n", "\n")
  return normalized if normalized.include?("\n\n")
  normalized.split("\n").join("\n\n")
end

def ensure_trailing_ellipsis(text)
  clean = text.to_s.strip
  return "" if clean.empty?
  clean = clean.gsub(/\u2026/, "...")
  clean = clean.sub(/[.!?…]+\z/, "")
  "#{clean}..."
end

def ensure_trailing_period(text)
  clean = text.to_s.strip
  return "" if clean.empty?
  clean.end_with?(".", "!", "?") ? clean : "#{clean}."
end

def social_message(title:, blurb:, link:)
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

def normalize_episode_next_teaser(text)
  teaser = text.to_s.strip
  base = DEFAULT_NEXT_TEASER
  full = if teaser.empty?
           base
         else
           teaser.start_with?(base) ? teaser : "#{base} #{teaser}"
         end
  ensure_trailing_period(full)
end

def normalize_image_path(value)
  path = value.to_s.strip
  return DEFAULT_IMAGE_PATH if path.empty?
  return path if path.start_with?("http://", "https://")
  path.start_with?("/") ? path : "/#{path}"
end

def ensure_drafts_dir
  FileUtils.mkdir_p(DRAFTS_DIR)
  migrate_legacy_drafts
end

def draft_file_path(draft_id)
  raise ArgumentError, "draft_id is required" if draft_id.to_s.strip.empty?
  File.join(DRAFTS_DIR, "#{draft_id}.json")
end

def delete_draft_interactively(drafts)
  if drafts.empty?
    puts "No drafts available to delete."
    return false
  end
  print("Enter the number of the draft to delete: ")
  input = STDIN.gets&.strip
  exit 1 if input.nil?
  if input.empty?
    puts "Deletion cancelled."
    return false
  end
  index = input.to_i
  if index < 1 || index > drafts.length
    puts "Invalid selection. Enter a number between 1 and #{drafts.length}."
    return false
  end
  draft = drafts[index - 1]
  state = draft[:state] || {}
  title = state[:full_title] || state[:slug] || state[:draft_id] || File.basename(draft[:path])
  unless prompt_yes_no("Delete draft \"#{title}\"?", default: false)
    puts "Deletion cancelled."
    return false
  end
  begin
    File.delete(draft[:path])
    puts "Deleted draft #{title}."
    true
  rescue StandardError => e
    warn "Failed to delete draft: #{e.message}"
    false
  end
end

def migrate_legacy_drafts
  LEGACY_DRAFT_PATHS.each do |legacy_dir|
    next if legacy_dir == DRAFTS_DIR
    next unless Dir.exist?(legacy_dir)
    legacy_files = Dir.glob(File.join(legacy_dir, "*.json"))
    next if legacy_files.empty?
    puts "Migrating #{legacy_files.length} draft(s) from #{legacy_dir}..."
    legacy_files.each do |legacy|
      target = File.join(DRAFTS_DIR, File.basename(legacy))
      if File.exist?(target)
        FileUtils.rm_f(legacy)
      else
        FileUtils.mv(legacy, target)
      end
    rescue StandardError => e
      warn "Failed to migrate draft #{legacy}: #{e.message}"
    end
    begin
      Dir.rmdir(legacy_dir) if Dir.exist?(legacy_dir) && Dir.empty?(legacy_dir)
    rescue StandardError
      # directory not empty or cannot be removed; ignore
    end
  end
rescue StandardError => e
  warn "Draft migration error: #{e.message}"
end

def load_draft_state(path)
  data = JSON.parse(File.read(path), symbolize_names: true)
  data[:draft_id] ||= File.basename(path, ".json")
  data
rescue StandardError => e
  warn "Skipping draft #{path}: #{e.message}"
  nil
end

def available_drafts
  ensure_drafts_dir
  Dir.glob(File.join(DRAFTS_DIR, "*.json")).map do |path|
    state = load_draft_state(path)
    next unless state
    saved_at = state[:draft_saved_at] || File.mtime(path).iso8601
    { path: path, state: state, saved_at: saved_at }
  end.compact.sort_by { |draft| draft[:saved_at].to_s }.reverse
end

def serializable_draft_state(state)
  data = state.dup
  publish_date = data[:publish_date]
  data[:publish_date] = if publish_date.respond_to?(:iso8601)
                          publish_date.iso8601
                        else
                          publish_date.to_s
                        end
  data
end

def save_draft(state)
  ensure_drafts_dir
  state[:draft_id] = SecureRandom.uuid if state[:draft_id].to_s.strip.empty?
  timestamp = alaska_time
  state[:draft_saved_at] = timestamp.iso8601
  serializable = serializable_draft_state(state)
  path = draft_file_path(state[:draft_id])
  File.write(path, JSON.pretty_generate(serializable))
  puts "Saved draft #{state[:full_title] || state[:slug] || state[:draft_id]} to #{path}"
  path
end

def delete_draft_file(state)
  return unless state[:draft_id]
  path = draft_file_path(state[:draft_id])
  File.delete(path) if File.exist?(path)
rescue Errno::ENOENT
  nil
end

def load_front_matter(path)
  content = File.read(path)
  match = content.match(/\A---\s*\n(.*?)\n---\s*/m)
  return {} unless match
  YAML.safe_load(match[1], aliases: true) || {}
end

def next_episode_number
  episodes = Dir.glob(File.join(POSTS_DIR, "*.md")).filter_map do |file|
    fm = load_front_matter(file)
    fm["episode"]&.to_i
  end
  (episodes.max || 0) + 1
end

def max_episode_date
  dates = Dir.glob(File.join(POSTS_DIR, "*.md")).filter_map do |file|
    fm = load_front_matter(file)
    next unless fm["episode"]
    Date.parse(File.basename(file)[0, 10])
  rescue ArgumentError
    nil
  end
  dates.compact.max
end

def episode_next_date
  file = Dir.glob(NEXT_GLOB).first
  return nil unless file
  Date.parse(File.basename(file)[0, 10])
rescue ArgumentError
  nil
end

def ensure_date(after_date)
  today = Date.today
  return today unless after_date
  date = after_date + 1
  date > today ? date : today
end

def openai_api_key
  return @openai_api_key if defined?(@openai_api_key)
  env_key = ENV["OPENAI_API_KEY"]&.strip
  return @openai_api_key = env_key unless env_key.nil? || env_key.empty?
  @openai_api_key = File.read(API_KEY_PATH).strip
rescue Errno::ENOENT
  nil
end

def log_openai_interaction(payload:, response:, error: nil, tags: nil)
  FileUtils.mkdir_p(LOG_DIR)
  timestamp = alaska_time
  label = timestamp.strftime(LOG_TIME_FORMAT)
  filename = File.join(LOG_DIR, "openai_#{label}.log")
  log_text = format_log_entry(timestamp: timestamp, payload: payload, response: response, error: error, tags: tags)
  File.write(filename, log_text + "\n")
  prune_logs
rescue StandardError => e
  warn "Logging failed: #{e.message}"
end

def prune_logs
  files = Dir.glob(File.join(LOG_DIR, "openai_*.log")).sort.reverse
  return if files.size <= MAX_LOG_FILES
  files[MAX_LOG_FILES..]&.each { |file| File.delete(file) rescue nil }
end

def format_log_entry(timestamp:, payload:, response:, error:, tags: nil)
  lines = []
  lines << "timestamp: #{timestamp.iso8601}"

  model = (payload && (payload["model"] || payload[:model])) rescue nil
  lines << "model: #{model}" if model
  lines << "" if model

  system_text = extract_message_content(payload, "system")
  lines << "content(system): #{system_text}" unless system_text.empty?

  user_text = extract_message_content(payload, "user")
  lines << "content(user): #{user_text}" unless user_text.empty?

  summary = response_summary(response)
  response_text = summary[:content].to_s
  human_response = if tags && !tags.empty?
                     tags.join(", ")
                   else
                     parsed = parse_tags_from_response(response_text)
                     parsed.any? ? parsed.join(", ") : response_text
                   end
  unless human_response.nil? || human_response.empty?
    lines << ""
    lines << "response: #{human_response}"
  end

  lines.join("\n")
end

def extract_message_content(payload, role)
  return "" unless payload
  messages = payload["messages"] || payload[:messages] || payload["input"] || payload[:input]
  return "" unless messages
  Array(messages).map do |msg|
    msg_role = msg["role"] || msg[:role]
    next unless msg_role == role
    content = msg["content"] || msg[:content]
    content = Array(content).map { |part| part.is_a?(Hash) ? part["text"] || part[:text] : part }.join("\n")
    content.to_s.strip
  end.compact.reject(&:empty?).join("\n\n---\n\n")
end

def response_summary(response)
  summary = {}
  return summary unless response

  data = case response
         when String
           JSON.parse(response) rescue nil
         when Hash
           response
         else
           nil
         end

  if data
    outputs = data["output"] || data["outputs"]
    if outputs && !outputs.empty?
      first = outputs.first
      summary[:finish_reason] = first["finish_reason"] if first["finish_reason"]
      content = extract_output_text(first)
      summary[:content] = content unless content.empty?
    elsif (choice = data.dig("choices", 0))
      summary[:finish_reason] = choice["finish_reason"] if choice["finish_reason"]
      content = choice.dig("message", "content").to_s.strip
      summary[:content] = content unless content.empty?
    end

    if (usage = data["usage"])
      summary[:usage] = {
        prompt: usage["input_tokens"] || usage["prompt_tokens"],
        completion: usage["output_tokens"] || usage["completion_tokens"],
        total: usage["total_tokens"],
        reasoning: usage.dig("output_tokens_details", "reasoning_tokens") || usage.dig("completion_tokens_details", "reasoning_tokens")
      }.compact
    end

    unless summary[:content]
      reason = summary[:finish_reason] ? "finish_reason=#{summary[:finish_reason]}" : "no-finish-reason"
      summary[:content] = "(no content returned; #{reason})"
    end
  else
    summary[:content] = response.to_s
  end

  summary
end

def tag_prompt_text(body:, blurb:)
  <<~PROMPT
    You are helping publish a serialized science-fiction story. Return JSON that matches the provided schema.
    Constraints:
    - Exactly #{MIN_EXTRA_TAGS} unique tags.
    - Lowercase kebab-case (letters, numbers).
    - No hyphens, single words only.
    - Do NOT reuse these defaults: #{DEFAULT_TAGS.map(&:downcase).join(", ")}.
    - Considering the themes of corporate bureaucracy, technology, and Alaska, generate tags using the short blurb and body below.

    Short blurb:
    #{blurb}

    Body:
    #{body}
  PROMPT
end

def openai_tag_payload(body:, blurb:)
  {
    model: AI_MODEL,
    temperature: AI_TEMPERATURE,
    max_output_tokens: AI_MAX_OUTPUT_TOKENS,
    text: {
      format: {
        type: "json_schema",
        name: TAG_JSON_SCHEMA[:name] || TAG_JSON_SCHEMA["name"],
        schema: TAG_JSON_SCHEMA[:schema] || TAG_JSON_SCHEMA["schema"]
      }
    },
    metadata: { purpose: "episode_tags" },
    input: [
      {
        role: "system",
        content: [
          { type: "input_text", text: "You are a helpful assistant that returns concise topic tags as JSON." }
        ]
      },
      {
        role: "user",
        content: [
          { type: "input_text", text: tag_prompt_text(body: body, blurb: blurb) }
        ]
      }
    ]
  }
end

def send_openai_request(payload, api_key)
  http = Net::HTTP.new(OPENAI_URI.host, OPENAI_URI.port)
  http.use_ssl = OPENAI_URI.scheme == "https"
  request = Net::HTTP::Post.new(OPENAI_URI.request_uri)
  request["Content-Type"] = "application/json"
  request["Authorization"] = "Bearer #{api_key}"
  request.body = JSON.dump(payload)
  http.request(request)
end

def parse_tags_from_response(content)
  json = JSON.parse(content) rescue nil
  if json.is_a?(Hash) && json["tags"].is_a?(Array)
    return json["tags"].map { |tag| tag.to_s.strip }.reject(&:empty?)
  end
  content.split(/[,\n]/).map { |tag| tag.to_s.strip }.reject(&:empty?)
end

def fallback_tags_from_body(body:, blurb:)
  reserved = DEFAULT_TAGS.map { |tag| tag.downcase }
  counts = Hash.new(0)
  combined_text = "#{body}\n\n#{blurb}"
  combined_text.downcase.scan(/[a-z0-9]{4,}/).each do |word|
    next if reserved.include?(word)
    counts[word] += 1
  end
  counts.sort_by { |word, count| [-count, word] }.map(&:first).first(MIN_EXTRA_TAGS)
end

def extract_output_text(output)
  return "" unless output && output["content"]
  output["content"].map do |chunk|
    case chunk["type"]
    when "output_json", "json"
      json = chunk["json"]
      json.is_a?(Hash) ? JSON.pretty_generate(json) : json.to_s
    when "output_text", "text"
      chunk["text"].to_s
    else
      chunk["text"] || chunk["json"].to_s rescue ""
    end
  end.compact.reject(&:empty?).join("\n\n")
end

def extract_tags_from_openai(data)
  outputs = data["output"] || data["outputs"]
  if outputs
    outputs.each do |output|
      next unless output["content"]
      output["content"].each do |chunk|
        case chunk["type"]
        when "output_json", "json"
          json = chunk["json"]
          if json.is_a?(Hash) && json["tags"].is_a?(Array)
            tags = json["tags"].map { |tag| tag.to_s.strip }.reject(&:empty?)
            return tags unless tags.empty?
          end
        when "output_text", "text"
          tags = parse_tags_from_response(chunk["text"].to_s)
          return tags unless tags.empty?
        end
      end
    end
  end

  if (choices = data["choices"])
    choices.each do |choice|
      content = choice.dig("message", "content").to_s
      tags = parse_tags_from_response(content)
      return tags unless tags.empty?
    end
  end

  []
end

def update_episode_next_teaser(new_text)
  clean_text = new_text.to_s.strip
  return if clean_text.empty?
  unless File.exist?(EPISODE_NEXT_PATH)
    warn "episodeNEXT file not found at #{EPISODE_NEXT_PATH}"
    return
  end

  raw = File.read(EPISODE_NEXT_PATH)
  match = raw.match(/\A(---\s*\n.*?\n---\s*\n)(.*)\z/m)
  unless match
    warn "episodeNEXT front matter not found; no changes made."
    return
  end
  front_raw, body_raw = match.captures

  blurb_pattern = /(blurb:\s*&blurb\s*>-\s*\n)(?: {2}.*\n)+/
  unless front_raw =~ blurb_pattern
    warn "episodeNEXT blurb block not found; no changes made."
    return
  end
  front_updated = front_raw.sub(blurb_pattern) { "#{$1}  #{clean_text}\n" }

  body_lines = body_raw.lines
  first_text_index = body_lines.index { |line| !line.strip.empty? }
  if first_text_index
    leading = body_lines[first_text_index][/^\s*/] || ""
    body_lines[first_text_index] = "#{leading}#{clean_text}\n"
  else
    body_lines.unshift("#{clean_text}\n")
  end
  body_updated = body_lines.join

  File.write(EPISODE_NEXT_PATH, front_updated + body_updated)
  puts "Updated episodeNEXT teaser."
end

def generate_extra_tags(body:, blurb:)
  key = openai_api_key
  return [] unless key && !key.empty?

  payload = openai_tag_payload(body: body, blurb: blurb)
  response = nil

  puts "Contacting OpenAI (#{AI_MODEL}) for tag suggestions..."
  response = send_openai_request(payload, key)
  unless response.is_a?(Net::HTTPSuccess)
    log_openai_interaction(payload: payload, response: response.body, error: "HTTP #{response.code}")
    raise "OpenAI error #{response.code}: #{response.body}"
  end

  data = JSON.parse(response.body)
  tags = extract_tags_from_openai(data).map(&:downcase).uniq.first(MIN_EXTRA_TAGS)
  if tags.empty?
    finish_reason = data.dig("output", 0, "finish_reason") || data.dig("outputs", 0, "finish_reason") || data.dig("choices", 0, "finish_reason")
    log_openai_interaction(
      payload: payload,
      response: response.body,
      error: "No tags returned (finish_reason=#{finish_reason || 'unknown'})"
    )
    return []
  end

  log_openai_interaction(payload: payload, response: response.body, tags: tags)
  tags
rescue StandardError => e
  log_openai_interaction(payload: payload, response: response&.body, error: e.message) if payload
  warn "Tag generation failed: #{e.message}"
  []
end

def review_tags(extra_tags)
  tags = extra_tags.dup
  loop do
    puts "\nSuggested tags:"
    tags.each_with_index do |tag, index|
      puts "#{index + 1}. #{tag}"
    end
    print("Press Enter to accept all, or enter tag number to edit: ")
    input = STDIN.gets&.strip
    exit 1 if input.nil?
    return tags if input.empty?
    index = input.to_i
    if index <= 0 || index > tags.length
      puts "Invalid selection. Enter a number between 1 and #{tags.length}, or press Enter."
      next
    end
    print("Enter replacement for tag #{index}: ")
    replacement = STDIN.gets&.strip
    exit 1 if replacement.nil?
    replacement = replacement.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9-]/, "")
    if replacement.empty?
      puts "Tag cannot be empty."
      next
    end
    tags[index - 1] = replacement
  end
end

def build_tags_for_body(body:, blurb_input:)
  extra_tags = generate_extra_tags(body: body, blurb: blurb_input)
  if extra_tags.empty?
    warn "AI did not return tags; falling back to heuristic tags."
    extra_tags = fallback_tags_from_body(body: body, blurb: blurb_input)
    log_openai_interaction(
      payload: { "source" => "fallback-heuristic" },
      response: { "tags" => extra_tags }.to_json,
      tags: extra_tags,
      error: "heuristic-tags"
    ) unless extra_tags.empty?
  end
  extra_tags = (extra_tags + Array.new(MIN_EXTRA_TAGS, nil)).compact.first(MIN_EXTRA_TAGS)
  reviewed = review_tags(extra_tags)
  tags = (DEFAULT_TAGS + reviewed).map { |tag| tag.strip }.reject(&:empty?).uniq
  [reviewed, tags]
end

def review_answers(state)
  loop do
    tags_display = state[:tags].empty? ? "(none)" : state[:tags].join(", ")
    puts "\nReview answers (body preview truncated):"
    puts "Episode #: #{state[:episode_num]}"
    puts "Publish date: #{state[:publish_date]}"
    puts "Slug: #{state[:slug]}"
    puts "1. Episode title: #{state[:full_title]}"
    puts "2. Blurb: #{state[:blurb]}"
    puts "3. Image: #{state[:image_path]}"
    puts "4. Tags: #{tags_display}"
    puts "5. episodeNEXT teaser: #{state[:next_teaser]}"
    body_preview = state[:body].to_s.strip
    preview_text = if body_preview.empty?
                     "(empty)"
                   else
                     body_preview.lines.first(3).map(&:strip).join(" / ")
                   end
    preview_text = preview_text[0, 120]
    preview_text = "#{preview_text}..." if state[:body].to_s.strip.length > preview_text.length
    puts "6. Body: #{preview_text}"
    print("Enter number to edit, or press Enter to continue: ")
    input = STDIN.gets&.strip
    exit 1 if input.nil?
    return if input.empty?

    case input
    when "1"
      state[:title_fragment] = prompt('Episode title (without "episodeXXX - ")', required: true)
      state[:full_title] = format("episode%03d – %s", state[:episode_num], state[:title_fragment].strip)
      slug_suffix = SiteSupport.slugify(state[:title_fragment])
      state[:slug] = format("episode%03d-#{slug_suffix}", state[:episode_num])
      state[:blurb_input], state[:blurb] = enforce_social_limits_for_blurb(
        title: state[:full_title],
        initial_input: state[:blurb_input]
      )
    when "2"
      new_input = prompt('Blurb (without punctuation, e.g., "In which our abcxyz")', required: true)
      state[:blurb_input], state[:blurb] = enforce_social_limits_for_blurb(
        title: state[:full_title],
        initial_input: new_input
      )
    when "3"
      image_input = prompt("Image filename with extension (enter for default):", default: state[:image_path])
      state[:image_path] = normalize_image_path(image_input)
    when "4"
      state[:extra_tags] = review_tags(state[:extra_tags].dup)
      state[:tags] = (DEFAULT_TAGS + state[:extra_tags]).map { |tag| tag.strip }.reject(&:empty?).uniq
    when "5"
      next_input = prompt("episodeNEXT teaser", default: state[:next_teaser], required: true)
      state[:next_teaser] = normalize_episode_next_teaser(next_input)
    when "6"
      state[:body] = prompt_body_input(label: "Paste the full Markdown body (this replaces the existing body)")
      if prompt_yes_no("Regenerate tags based on the updated body?", default: true)
        state[:extra_tags], state[:tags] = build_tags_for_body(
          body: state[:body],
          blurb_input: state[:blurb_input]
        )
      else
        puts "Keeping existing tags. Use option 4 if you need to edit them."
      end
    else
      puts "Invalid selection. Choose 1-6 or press Enter."
    end
  end
end

def social_length_overages(title:, blurb:)
  limits = {
    "X" => X_CHAR_LIMIT,
    "Bluesky" => BLUESKY_CHAR_LIMIT
  }
  limits.each_with_object({}) do |(network, limit), memo|
    next unless limit && limit.positive?
    message = social_message(title: title, blurb: blurb, link: BASE_URL)
    length = message.length
    over = length - limit
    memo[network] = { length: length, limit: limit, over: over } if over.positive?
  end
end

def enforce_social_limits_for_blurb(title:, initial_input:)
  input = initial_input
  loop do
    formatted = ensure_trailing_ellipsis(input)
    overages = social_length_overages(title: title, blurb: formatted)
    return [input, formatted] if overages.empty?

    puts "\nSocial post warning:"
    overages.each do |network, data|
      puts "  #{network} summary is #{data[:over]} characters over the #{data[:limit]} character limit (#{data[:length]} total)."
    end
    puts "Edit the blurb to continue."
    input = prompt('Blurb (without punctuation, e.g., "In which our abcxyz")', required: true)
  end
end

def gather_initial_state
  episode_num     = next_episode_number
  last_episode    = max_episode_date
  next_placeholder = episode_next_date
  must_follow     = [last_episode, next_placeholder].compact.max

  puts "Preparing episode #{episode_num} (will follow all numbered episodes and precede episodeNEXT)."
  title_fragment = prompt('Episode title (without "episodeXXX - ")', required: true)
  full_title     = format("episode%03d – %s", episode_num, title_fragment.strip)
  slug_suffix    = SiteSupport.slugify(title_fragment)
  slug           = format("episode%03d-#{slug_suffix}", episode_num)
  publish_date   = ensure_date(must_follow)
  publish_date_str = publish_date.respond_to?(:iso8601) ? publish_date.iso8601 : publish_date.to_s

  blurb_input = prompt('Blurb (without punctuation, e.g., "In which our abcxyz")', required: true)
  blurb_input, blurb = enforce_social_limits_for_blurb(title: full_title, initial_input: blurb_input)

  body = prompt_body_input
  extra_tags, tags = build_tags_for_body(body: body, blurb_input: blurb_input)

  image_input = prompt("Image filename with extension (enter for default):", default: DEFAULT_IMAGE_PATH)
  image_path = normalize_image_path(image_input)

  default_teaser = DEFAULT_NEXT_TEASER
  next_teaser_input = prompt("episodeNEXT teaser", default: default_teaser, required: true)
  next_teaser = normalize_episode_next_teaser(next_teaser_input)

  {
    episode_num: episode_num,
    publish_date: publish_date_str,
    title_fragment: title_fragment,
    full_title: full_title,
    slug: slug,
    blurb_input: blurb_input,
    blurb: blurb,
    body: body,
    extra_tags: extra_tags,
    tags: tags,
    image_path: image_path,
    next_teaser: next_teaser,
    draft_id: nil,
    draft_saved_at: nil
  }
end

def select_initial_state
  loop do
    drafts = available_drafts
    if drafts.empty?
      puts "No saved drafts found. Starting a new episode."
      return gather_initial_state
    end

    puts "\nSaved drafts:"
    drafts.each_with_index do |draft, index|
      state = draft[:state]
      title = state[:full_title] || state[:slug] || "(untitled)"
      saved_at = draft[:saved_at]
      puts "#{index + 1}. #{title} (saved #{saved_at})"
    end
    puts "#{drafts.length + 1}. Start a new draft"

    print("Select draft number, press Enter for new, type N for new, or D to delete a draft: ")
    input = STDIN.gets&.strip
    exit 1 if input.nil?
    return gather_initial_state if input.empty? || input.casecmp("n").zero?

    if input.casecmp("d").zero?
      delete_draft_interactively(drafts)
      next
    end

    index = input.to_i
    if index == drafts.length + 1
      return gather_initial_state
    elsif index >= 1 && index <= drafts.length
      state = drafts[index - 1][:state]
      puts "Loaded draft #{state[:full_title] || state[:slug] || state[:draft_id]}."
      return state
    end
    puts "Invalid selection. Choose 1-#{drafts.length + 1}, press Enter, or type N."
  end
end

def prompt_final_action
  loop do
    print("\nChoose action: [P]ublish now, [S]ave draft, [Q]uit without saving: ")
    input = STDIN.gets&.strip
    exit 1 if input.nil?
    return :publish if input.empty?
    normalized = input.downcase
    return :publish if %w[p publish].include?(normalized)
    return :save if %w[s save].include?(normalized)
    return :quit if %w[q quit].include?(normalized)
    puts "Please enter P, S, or Q."
  end
end

def publish_episode(state)
  episode_num = state[:episode_num]
  publish_date = state[:publish_date]
  publish_date_str = if publish_date.respond_to?(:iso8601)
                       publish_date.iso8601
                     else
                       publish_date.to_s
                     end
  slug = state[:slug]
  filename = "#{publish_date_str}-#{slug}.md"
  filepath = File.join(POSTS_DIR, filename)

  if File.exist?(filepath)
    puts "Error: #{filename} already exists."
    return false
  end

  blurb = state[:blurb].to_s
  blurb_block = blurb.split("\n").map { |line| "  #{line.rstrip}" }.join("\n")
  tags = state[:tags] || []
  tags_block = if tags.empty?
                 "  - misc"
               else
                 tags.map { |tag| "  - #{tag}" }.join("\n")
               end

  body = state[:body].to_s
  post_content = <<~POST
    ---
    layout: post
    title: "#{state[:full_title]}"
    episode: #{episode_num}
    slug: #{slug}
    blurb: &blurb >-
    #{blurb_block}
    description: *blurb
    image: "#{state[:image_path]}"
    tags:
    #{tags_block}
    ---
    #{body.rstrip}
  POST

  File.write(filepath, post_content + "\n")

  update_episode_next_teaser(state[:next_teaser])

  puts "Created #{filepath}"

  crosspost_script = File.join(ROOT, "scripts", "generate_crossposts.rb")
  if system("ruby", crosspost_script)
    puts "Ran generate_crossposts script."
  else
    warn "Failed to run generate_crossposts script."
  end
  true
end

state = select_initial_state

review_answers(state)

loop do
  action = prompt_final_action
  case action
  when :publish
    if publish_episode(state)
      delete_draft_file(state)
      break
    end
  when :save
    save_draft(state)
    break
  when :quit
    puts "Exited without saving or publishing."
    break
  end
end
