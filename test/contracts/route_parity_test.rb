# frozen_string_literal: true

require_relative '../test_helper'

# D2 route-parity 契约测试（suite-hard-rules §4 落法）：
# 读 lib/generated/api_manifest.json（生成物，SSOT=shared openapi.yaml），逐条断言
# (1) verb+path 路由存在 (2) controller#action 已定义 (3) 多出来的路由红（/health allowlist）。
# Rails 无编译步，这是「缺端点红 / 私端点也红」的等价强制。
class RouteParityTest < ActionDispatch::IntegrationTest
  MANIFEST = JSON.parse(
    Rails.root.join('lib/generated/api_manifest.json').read
  ).freeze

  # /health 是 contract-test healthcheck 探针，非 OpenAPI 契约面 —— 唯一合法私路由
  EXTRA_ROUTE_ALLOWLIST = ['GET /health'].freeze

  test 'every manifest operation has a route and a defined action' do
    manifest_routes = {}
    MANIFEST['operations'].each do |op|
      pattern = "#{op['method']} #{manifest_pattern(op)}"
      manifest_routes[pattern] = op
    end

    manifest_routes.each do |pattern, op|
      verb, path = pattern.split(' ', 2)
      route = recognize_route(verb, path)
      assert route, "manifest #{pattern} (#{op['operationId']}) has no matching Rails route"

      controller = "#{route[:controller].camelize}Controller".constantize
      assert controller.method_defined?(route[:action]),
             "#{controller}##{route[:action]} not defined (#{op['operationId']})"
    end
  end

  test 'no undeclared routes beyond the allowlist' do
    declared = MANIFEST['operations'].map do |op|
      "#{op['method']} #{normalize_path(manifest_pattern(op))}"
    end.sort.uniq

    actual = Rails.application.routes.routes.filter_map do |r|
      verb = r.verb.to_s.split('|').first
      spec = r.path.spec.to_s
      next if verb.blank? || r.defaults.blank? || spec.start_with?('/rails/')

      "#{verb} #{normalize_path(spec)}"
    end.sort.uniq

    extras = actual - declared - EXTRA_ROUTE_ALLOWLIST
    assert_empty extras, "routes not in shared contract: #{extras.join(', ')}"
  end

  private

  # manifest 路径 {clientId} -> rails 动态段 :client_id
  def manifest_pattern(op)
    op['path'].gsub(/\{([^}]+)\}/) { ":#{Regexp.last_match(1).underscore}" }
  end

  def normalize_path(path)
    path.sub('(.:format)', '')
        .gsub(/:[A-Za-z_]+/, '{param}')
        .sub(%r{^/api/v1}, '')
  end

  def recognize_route(verb, path)
    match = Rails.application.routes.recognize_path(path, method: verb.downcase.to_sym)
    return nil if match.is_a?(Array) ? match.empty? : match.blank?

    (match.is_a?(Array) ? match.first : match).symbolize_keys
  rescue ActionController::RoutingError
    nil
  end
end
