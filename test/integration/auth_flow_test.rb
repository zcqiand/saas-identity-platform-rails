# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'support'

# M01.F04 登录语义集成测试（真库 saas_test）。
class AuthFlowTest < ActionDispatch::IntegrationTest
  include IntegrationSupport

  test 'login returns family response shape' do
    body = login
    assert_equal 200, response.status
    assert_equal DEV_USER, body['user']['username']
    assert_equal 'Bearer', body['tokenType']
    assert body['accessToken'].present?
    assert body['refreshToken'].present?
    assert_equal ENV.fetch('JWT_TTL_SECONDS').to_i, body['expiresIn']
    assert body['availableTenants'].is_a?(Array)
    assert body['availableTenants'].first['tenantId'].present?
  end

  test 'wrong password and unknown user share 401 semantics' do
    login(password: 'nope')
    assert_equal 401, response.status
    assert_equal 'INVALID_CREDENTIALS', JSON.parse(response.body)['code']

    login(username: 'ghost')
    assert_equal 401, response.status
    assert_equal 'INVALID_CREDENTIALS', JSON.parse(response.body)['code']
  end

  test 'unknown clientId is 400' do
    post '/api/v1/auth/login',
         params: { username: DEV_USER, password: DEV_PASSWORD, clientId: 'ghost-app' }, as: :json
    assert_equal 400, response.status
  end

  test 'five consecutive failures lock the account with 423 empty body' do
    user = SysUser.create!(username: 'lockme', password: 'plain:pw', email: 'lockme@x', status: 1, failed_attempts: 0)
    5.times do
      login(username: 'lockme', password: 'wrong')
      assert_equal 401, response.status
    end
    login(username: 'lockme', password: 'pw')
    assert_equal 423, response.status
    assert_empty response.body
    assert user.reload.locked_until > Time.now
  end

  test 'logout is 204 and protected routes require JWT' do
    post '/api/v1/auth/logout'
    assert_equal 204, response.status

    get '/api/v1/me'
    assert_equal 401, response.status
    assert_equal 'INVALID_CREDENTIALS', JSON.parse(response.body)['code']
  end

  test 'tenant mismatch on tenant-scoped route is 403' do
    body = login
    other = Tenant.where.not(id: alice_tenant_id).first!
    get "/api/v1/tenants/#{other.id}/members", headers: auth_header(body['accessToken'])
    assert_equal 403, response.status
    assert_equal 'FORBIDDEN', JSON.parse(response.body)['code']
  end
end
