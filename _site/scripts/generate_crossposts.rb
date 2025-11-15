#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "date"
require "time"
require "fileutils"
require_relative "lib/site_support"

ROOT = SiteSupport::ROOT
POSTS_DIR = SiteSupport::POSTS_DIR
OUTPUT_ROOT = SiteSupport::CROSSPOSTS_DIR
BASE_URL = SiteSupport::BASE_URL
SECTION_DIVIDER = "============%<==============="

CHANNELS = {
  "medium" => "med",
  "substack" => "sub",
  "wattpad" => "watt",
  "facebook" => "fb",
  "x" => "x",
  "bluesky" => "bsky"
}.freeze

def read_posts
  Dir.glob(File.join(POSTS_DIR, "*.md")).sort.map do |path|
    raw = File.read(path, encoding: "UTF-8")
    front_matter, body = extract_front_matter(raw)
    data = YAML.safe_load(front_matter, permitted_classes: [Date, Time], aliases: true) || {}

    {
      source_path: path,
      filename: File.basename(path),
      title: SiteSupport.normalize_plaintext(data.fetch("title", "").to_s.strip),
      slug: determine_slug(data, path),
      blurb: SiteSupport.normalize_plaintext(extract_blurb(data)),
      tags: Array(data["tags"]).map { |tag| tag.to_s.strip }.reject(&:empty?),
      content: SiteSupport.normalize_plaintext(body.strip)
    }
  end
end

def extract_front_matter(raw)
  match = raw.match(/\A---\s*\n(?<front>.+?)\n---\s*\n/m)
  raise "Missing front matter delimiter in post" unless match

  front_matter = match[:front]
  content = raw[match.end(0)..] || ""
  [front_matter, content]
end

def determine_slug(data, path)
  return data["slug"].to_s.strip unless data["slug"].to_s.strip.empty?

  candidate =
    if data["title"].to_s.strip.empty?
      File.basename(path, File.extname(path)).sub(/^\d{4}-\d{2}-\d{2}-/, "")
    else
      data["title"].to_s
    end

  SiteSupport.slugify(candidate)
end

def extract_blurb(data)
  (data["blurb"] || data["description"] || "").to_s.strip
end

def ensure_output_directories
  FileUtils.rm_rf(OUTPUT_ROOT)
  FileUtils.mkdir_p(OUTPUT_ROOT)
end

def build_payload(post, channel)
  title = post[:title]
  content = post[:content]
  blurb = SiteSupport.append_ellipses(post[:blurb])
  tags = post[:tags]
  link = BASE_URL

  case channel
  when "medium"
    formatted_sections(SECTION_DIVIDER, title, tags.join(", "), blurb, content)
  when "substack"
    formatted_sections(SECTION_DIVIDER, title, tags.join(", "), blurb, content)
  when "wattpad"
    formatted_sections(SECTION_DIVIDER, title, tags.join(", "), blurb, content)
  when "facebook"
    formatted_sections(SECTION_DIVIDER, title, tags.join(", "), blurb, content)
  when "x", "bluesky"
    SiteSupport.single_line_message(title, blurb, link)
  else
    ""
  end
end

def formatted_sections(separator, *values)
  values = values.map { |value| value.to_s.rstrip }
  values.join("\n#{separator}\n").strip
end

def write_channel_files(posts)
  counts = Hash.new(0)

  posts.each do |post|
    CHANNELS.each do |channel, segment|
      payload = build_payload(post, channel)
      next if payload.empty?

      post_dir = File.join(OUTPUT_ROOT, post[:slug])
      FileUtils.mkdir_p(post_dir)

      txt_path = File.join(post_dir, "#{segment}.txt")
      File.write(txt_path, SiteSupport.ensure_trailing_newline(payload.rstrip))
      counts[segment] += 1
    end
  end

  counts
end


def main
  posts = read_posts
  ensure_output_directories
  counts = write_channel_files(posts)

  puts "Generated crossposts:"
  CHANNELS.each_value do |segment|
    puts "  #{segment.ljust(9)} #{counts[segment]} files"
  end
end

main if $PROGRAM_NAME == __FILE__
