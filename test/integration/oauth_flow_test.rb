# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'support'

# M03 OAuth 双 grant 集成测试（真库）：code 一次性、redirect 白名单、refresh rotate。
class OauthFlowTest < ActionDispatch::IntegrationTest
  include IntegrationSupport

  def setup
    @token = login['accessToken']
    @client = OauthClient.find_by!(client_id: DEV_CLIENT)
  end

  test 'authorize issues a one-time code bound to redirect whitelist' do
    post '/api/v1/oauth/authorize',
         params: authorize_params(redirect_uri: first_redirect), headers: auth_header(@token), as: :json
    assert_equal 200, response.status
    code = JSON.parse(response.body)
    assert code['code'].start_with?('ac_')
    assert_equal 'xyz', code['state']

    # 交换
    post '/api/v1/oauth/token',
         params: { grantType: 'authorization_code', clientId: DEV_CLIENT,
                   code: code['code'], redirectUri: first_redirect }, as: :json
    assert_equal 200, response.status
    granted = JSON.parse(response.body)
    assert granted['accessToken'].present?
    assert_equal DEV_CLIENT, granted['clientId']
    assert_equal 'Bearer', granted['tokenType']

    # 重放 = 一次性消费
    post '/api/v1/oauth/token',
         params: { grantType: 'authorization_code', clientId: DEV_CLIENT,
                   code: code['code'], redirectUri: first_redirect }, as: :json
    assert_equal 400, response.status
    assert_equal 'INVALID_GRANT', JSON.parse(response.body)['code']
  end

  test 'redirect outside whitelist is 400' do
    post '/api/v1/oauth/authorize',
         params: authorize_params(redirect_uri: 'http://evil.example/cb'),
         headers: auth_header(@token), as: :json
    assert_equal 400, response.status
    # 镜像：INVALID_REDIRECT_URI 在 message（code 走 IAE 处理器的 BAD_REQUEST）
    assert_includes response.body, 'INVALID_REDIRECT_URI'
  end

  test 'refresh rotation revokes the old token' do
    login_body = login
    post '/api/v1/oauth/token',
         params: { grantType: 'refresh_token', clientId: DEV_CLIENT,
                   refreshToken: login_body['refreshToken'] }, as: :json
    assert_equal 200, response.status
    rotated = JSON.parse(response.body)
    # 镜像：login persistTokenPair 落行带 tenantId（springboot 先解析租户再落行），
    # refresh rotate 继承旧行 -> 响应必有 tenantId（M96.F02.I28 四方比对口径）
    assert rotated['tenantId'].present?, 'refresh response missing tenantId'

    post '/api/v1/oauth/token',
         params: { grantType: 'refresh_token', clientId: DEV_CLIENT,
                   refreshToken: login_body['refreshToken'] }, as: :json
    assert_equal 400, response.status
    assert_equal 'INVALID_GRANT', JSON.parse(response.body)['code']

    assert rotated['accessToken'].present?
  end

  # live M96.F02.I28 分叉根因：exchange 落行的 refresh 行漏 tenant_id
  # （I27 的 refreshToken 来自 code exchange；rotate 继承旧行 nil → normalize 剔除
  # → 四方比对 nextjs 有 tenantId 而 rails 无）。login 链断言覆盖不到这条链。
  test 'refresh of exchange-issued token carries tenantId' do
    post '/api/v1/oauth/authorize',
         params: authorize_params(redirect_uri: first_redirect), headers: auth_header(@token), as: :json
    assert_equal 200, response.status
    code = JSON.parse(response.body)['code']

    post '/api/v1/oauth/token',
         params: { grantType: 'authorization_code', clientId: DEV_CLIENT,
                   code: code, redirectUri: first_redirect }, as: :json
    assert_equal 200, response.status
    granted = JSON.parse(response.body)

    post '/api/v1/oauth/token',
         params: { grantType: 'refresh_token', clientId: DEV_CLIENT,
                   refreshToken: granted['refreshToken'] }, as: :json
    assert_equal 200, response.status
    rotated = JSON.parse(response.body)
    assert rotated['tenantId'].present?, 'exchange-issued refresh response missing tenantId'
  end

  test 'authorize without bearer or tenant claim is 401' do
    post '/api/v1/oauth/authorize', params: authorize_params(redirect_uri: first_redirect), as: :json
    assert_equal 401, response.status
  end

  private

  def authorize_params(redirect_uri:)
    { clientId: DEV_CLIENT, redirectUri: redirect_uri, responseType: 'code', state: 'xyz' }
  end

  def first_redirect
    @client.redirect_uris.split(',').first.strip
  end
end
