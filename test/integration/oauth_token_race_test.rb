# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'support'

# 5.123①② 竞态机制钉（tracker：rails 先行定形状，其余六栈同形镜像）：
# ① code 一次性消费的 claim 必须原子——「读到行但删除未生效」的输家不得再签 token 对
#   （Delete WHERE code=? + 影响行数判定）；② refresh 轮换的「撤销旧行 + 签发新对」两笔写
#   必须同事务——签发段失败要回滚恢复旧行。双花/中途故障均毫秒级窗口，HTTP 层注不进交错，
#   故以机制钉直接驱动 TokenService（stub 手写 ensure 恢复，本仓 bundler 布局无 minitest/mock）。
class OauthTokenRaceTest < ActionDispatch::IntegrationTest
  include IntegrationSupport

  def setup
    @token = login['accessToken']
    @client = OauthClient.find_by!(client_id: DEV_CLIENT)
  end

  test 'code claim is atomic: stale-row loser must not reissue tokens' do
    fn 'M04.F03.I02'
    post '/api/v1/oauth/authorize',
         params: authorize_params(redirect_uri: first_redirect), headers: auth_header(@token), as: :json
    assert_equal 200, response.status
    code = JSON.parse(response.body)['code']

    service = Oauth::TokenService.new(
      grantType: 'authorization_code', clientId: DEV_CLIENT,
      code: code, redirectUri: first_redirect
    )
    row_snapshot = OauthCode.find_by!(code: code)
    # 赢家先行消费：行已物理删除
    OauthCode.where(code: code).delete_all
    access_before = OauthAccessToken.count

    # 输家读到的仍是删除前的内存快照（并发窗口内 read-then-delete 的 deleted=0 形态）
    stub_class_method(OauthCode, :find_by, ->(*) { row_snapshot }) do
      err = assert_raises(Oauth::TokenService::TokenError) { service.call }
      assert_equal 'INVALID_GRANT', err.code
    end
    assert_equal access_before, OauthAccessToken.count, '输家不得再签 token 对'
  end

  test 'refresh rotation is atomic: failed issuance restores the old refresh token' do
    fn 'M04.F03.I03'
    login_body = login
    rt = login_body['refreshToken']

    failing = Oauth::TokenService.new(grantType: 'refresh_token', clientId: DEV_CLIENT, refreshToken: rt)
    boom = ->(*) { raise 'db fault mid-rotation' }
    stub_instance_method(Oauth::TokenService, :persist_token_pair, boom) do
      assert_raises(RuntimeError) { failing.call }
    end

    # 轮换段事务回滚：旧行 revoked 已还原 -> 同一 refresh 可再次轮换
    retry_service = Oauth::TokenService.new(grantType: 'refresh_token', clientId: DEV_CLIENT, refreshToken: rt)
    res = retry_service.call
    assert res[:access_token].present?, '签发段失败后旧 refresh 必须仍可用（回滚恢复）'
  end

  private

  # 手写 stub（ensure 恢复）：类方法
  def stub_class_method(klass, name, replacement)
    original = klass.method(name)
    klass.define_singleton_method(name, replacement)
    yield
  ensure
    klass.define_singleton_method(name, original)
  end

  # 手写 stub（ensure 恢复）：实例方法
  def stub_instance_method(klass, name, replacement)
    original = klass.instance_method(name)
    klass.define_method(name, replacement)
    yield
  ensure
    klass.define_method(name, original)
  end

  def authorize_params(redirect_uri:)
    { clientId: DEV_CLIENT, redirectUri: redirect_uri, responseType: 'code', state: 'xyz' }
  end

  def first_redirect
    @client.redirect_uris.split(',').first.strip
  end
end
