# frozen_string_literal: true

require 'uri'

require_relative '../test_helper'

# REQ-2026-001：后端根路径默认跳转 Swagger UI（匿名，三段式：302 / UI 页 200 / 契约副本可解析）。
# 基础设施端点，与 /health 同类 —— 刻意不进功能树（REQ §4，ADR-0027 subset invariant），
# 故本文件不挂任何功能 ID / fn 标记。
class RootSwaggerRedirectTest < ActionDispatch::IntegrationTest
  test 'root path redirects anonymous visitors to swagger ui' do
    get '/'
    assert_equal 302, response.status
    # Rails redirect 会把相对路径绝对化（带 integration test host），断言 path 部分
    assert_equal '/api-docs/index.html', URI.parse(response.location).path
  end

  test 'swagger ui entry page is served from vendored assets' do
    get '/api-docs/index.html'
    assert_equal 200, response.status
    assert_includes response.body, 'swagger-ui-bundle.js'
  end

  test 'openapi json copy is served, parseable and has non-empty paths' do
    get '/api-docs/openapi.json'
    assert_equal 200, response.status
    doc = JSON.parse(response.body)
    assert doc.key?('openapi')
    assert_not_empty doc['paths']
  end
end
