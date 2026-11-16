# Usage: ruby -Eutf-8:utf-8 validate_translation.rb <translations-source.json> <translations/xx.json>
# Checks: valid JSON, every key present and non-empty, format specifiers
# preserved (same count and types; order may change), ** markers preserved.
require "json"

source = JSON.parse(File.read(ARGV[0], encoding: "utf-8"))
begin
  t = JSON.parse(File.read(ARGV[1], encoding: "utf-8"))
rescue JSON::ParserError => e
  abort "INVALID JSON: #{e.message[0, 200]}"
end

def specs(s)
  s.scan(/%(?:\d+\$)?(?:lld|ld|d|@|lf|f)/).map { |x| x.sub(/\d+\$/, "") }.sort
end

problems = []
strings = t["strings"] || {}
source["strings"].each do |e|
  k = e["key"]
  v = strings[k]
  if v.nil? || v.strip.empty?
    problems << "MISSING: #{k}"
    next
  end
  problems << "SPECIFIERS (need #{specs(k).join(' ')}): #{k}" if specs(v) != specs(k)
  problems << "BOLD ** COUNT: #{k}" if v.scan("**").size != k.scan("**").size
  # Positional specifiers must be all-or-nothing within a string.
  pos = v.scan(/%\d+\$/).size
  all = v.scan(/%(?:\d+\$)?(?:lld|ld|d|@|lf|f)/).size
  problems << "MIXED POSITIONAL/PLAIN: #{k}" if pos > 0 && pos != all
end
extra = strings.keys - source["strings"].map { |e| e["key"] }
problems << "UNKNOWN KEYS (#{extra.size}), e.g. #{extra.first}" unless extra.empty?
info = t["infoplist"] || {}
source["infoplist"].each { |e| problems << "MISSING INFOPLIST: #{e['key']}" if info[e["key"]].to_s.strip.empty? }

if problems.empty?
  puts "OK: #{strings.size} strings, #{info.size} infoplist"
else
  puts "#{problems.size} problems:"
  puts problems.first(80)
  exit 1
end
