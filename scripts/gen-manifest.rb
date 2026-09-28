#!/usr/bin/env ruby
# frozen_string_literal: true

# OpenAPI -> API manifest generator (profiles/codegen.md section 1, rails row).
#
# openapi-generator has no mature Rails server generator (ruby-on-rails stale
# since 5.x, ruby-sinatra deprecated) -> self-built: reads shared openapi.yaml,
# emits lib/generated/api_manifest.json:
#   { "schema": 1, "operations": [ { operationId, method, path, tag,
#       requestSchema, responseSchema, requiredFields } ] }
#
# Deterministic output (L4.codegen.idempotent compares regen bytes):
# - fixed key order; operations sorted by [tag, operationId]
# - no timestamps; LF; UTF-8
#
# Usage: bundle exec ruby scripts/gen-manifest.rb <openapi.yaml> [--out DIR]
#   --out DIR  output dir (default lib/generated); kept for future tmpout mode
#              (the idempotency checker currently re-runs in place and diffs)

require "yaml"
require "json"
require "fileutils"

DEFAULT_OUT = "lib/generated"
HTTP_METHODS = %w[get post put patch delete].freeze

openapi_path = ARGV.shift or abort "usage: gen-manifest.rb <openapi.yaml> [--out DIR]"
out_dir = DEFAULT_OUT
while (arg = ARGV.shift)
  case arg
  when "--out" then out_dir = ARGV.shift or abort "--out needs a directory argument"
  end
end

spec = YAML.unsafe_load_file(openapi_path)
abort "ERROR: #{openapi_path} missing paths" unless spec["paths"]

operations = []
spec["paths"].each do |path, item|
  (item || {}).each do |method, op|
    next unless HTTP_METHODS.include?(method)

    req_ref = op.dig("requestBody", "content", "application/json", "schema", "$ref")
    resp_ref = op.dig("responses", "200", "content", "application/json", "schema", "$ref")
    request_schema_name = req_ref&.split("/")&.last

    # requiredFields: the request schema's required list (default [])
    required_fields = []
    if request_schema_name
      required_fields = spec.dig("components", "schemas", request_schema_name, "required") || []
    end

    operations << {
      "operationId" => op.fetch("operationId"),
      "method" => method.upcase,
      "path" => path,
      "tag" => op.fetch("tags").first,
      "requestSchema" => request_schema_name,
      "responseSchema" => resp_ref&.split("/")&.last,
      "requiredFields" => required_fields,
    }
  end
end

operations.sort_by! { |o| [o["tag"], o["operationId"]] }

manifest = { "schema" => 1, "operations" => operations }
out_path = File.join(out_dir, "api_manifest.json")
FileUtils.mkdir_p(File.dirname(out_path))
File.write(out_path, JSON.pretty_generate(manifest) + "\n")
puts "[gen-manifest] #{operations.size} operations -> #{out_path}"
