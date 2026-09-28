# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'support'

# 管理面 + me 面集成测试（真库）：分页信封、驼峰渲染、null 剔除、菜单树。
class AdminMeTest < ActionDispatch::IntegrationTest
  include IntegrationSupport

  def setup
    @token = login['accessToken']
  end

  test 'admin clients list returns family pagination envelope in camelCase' do
    get '/api/v1/admin/clients?page=0&pageSize=2', headers: auth_header(@token)
    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert_equal %w[items page pageSize total], body.keys.sort
    assert_equal 2, body['pageSize']
    assert body['items'].first.key?('clientId')
  end

  test 'create admin client applies family defaults and returns 200' do
    post '/api/v1/admin/clients',
         params: { clientId: 'spec-client', clientName: 'Spec', clientSecret: 's',
                   grantTypes: 'authorization_code,refresh_token', redirectUris: 'http://x/cb' },
         headers: auth_header(@token), as: :json
    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert_equal 3600, body['accessTokenValidity']
    assert_equal 86_400, body['refreshTokenValidity']
    assert_equal false, body['autoApprove']
    assert_equal 1, body['status']
  end

  test 'admin clients requires JWT' do
    get '/api/v1/admin/clients'
    assert_equal 401, response.status
  end

  test 'me whoami returns memberships and resolved tenant' do
    get '/api/v1/me', headers: auth_header(@token)
    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert_equal SysUser.find_by!(username: DEV_USER).id, body['id']
    assert body['memberships'].is_a?(Array)
    assert body['memberships'].first['roleIds'].is_a?(Array)
    assert body['currentTenantId'].present?
  end

  test 'me menus returns client-grouped tree with nulls stripped' do
    get '/api/v1/me/menus', headers: auth_header(@token)
    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert body.is_a?(Hash)
    first = body.values.flatten.first
    skip 'seeded user has no menu grants' if first.nil?

    assert first.key?('children')
    assert_not first.key?('parentId') if first['parentId'].nil?
  end

  test 'me tenants returns bare active membership array' do
    get '/api/v1/me/tenants', headers: auth_header(@token)
    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert body.is_a?(Array)
    assert_equal 'active', body.first['status']
  end

  test 'tenant members list filters by status db-side' do
    get "/api/v1/tenants/#{alice_tenant_id}/members?status=active", headers: auth_header(@token)
    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert(body['items'].all? { |m| m['status'] == 'active' })
  end

  test 'invalid uuid path param maps to 400 family error' do
    get '/api/v1/admin/tenants/not-a-uuid', headers: auth_header(@token)
    assert_equal 400, response.status
    assert_equal 'BAD_REQUEST', JSON.parse(response.body)['code']
  end
end
