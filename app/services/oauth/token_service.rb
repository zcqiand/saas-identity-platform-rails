# frozen_string_literal: true

# OAuth token 双 grant（springboot OauthController.token 镜像）：
# - authorization_code：code 一次性消费（交换/过期/redirect 不匹配均删行，重放 400）
#   code 绑 clientId；redirectUri 与 authorize 存库值逐字相等
# - refresh_token：revoked -> 400；rotate（旧行标 revoked，新行 client_id 沿用旧行，
#   scope 继承 access token 行）
module Oauth
  class TokenService
    def initialize(params)
      @grant_type = params[:grantType]
      @client_id = params[:clientId]
      @code = params[:code]
      @refresh_token = params[:refreshToken]
      @redirect_uri = params[:redirectUri]
    end

    def call
      raise invalid('INVALID_CLIENT', 'unknown clientId') if client_row.nil?

      case @grant_type
      when 'authorization_code' then exchange_code
      when 'refresh_token' then rotate_refresh
      else raise invalid('UNSUPPORTED_GRANT_TYPE', "unsupported grantType #{@grant_type}")
      end
    end

    private

    def exchange_code
      raise invalid('INVALID_REQUEST', 'code is required') if @code.blank?
      raise invalid('INVALID_REQUEST', 'redirectUri is required') if @redirect_uri.blank?

      row = consume_code_row
      issue(row.client_id, row.user_id, row.tenant_id, row.scope)
    end

    # code 一次性消费：过期/redirect 不匹配也删行（重放 400）
    def consume_code_row
      row = OauthCode.find_by(code: @code)
      raise invalid('INVALID_GRANT', 'code 不存在或已被使用') if row.nil? || row.client_id != @client_id

      if row.expires_at <= Time.now
        row.delete
        raise invalid('INVALID_GRANT', 'expired code')
      end
      unless ActiveSupport::SecurityUtils.secure_compare(row.redirect_uri.to_s, @redirect_uri.to_s)
        row.delete
        raise invalid('INVALID_GRANT', 'redirectUri mismatch')
      end

      row.delete
      row
    end

    def rotate_refresh
      raise invalid('INVALID_REQUEST', 'refreshToken is required') if @refresh_token.blank?

      row = OauthRefreshToken.find_by(refresh_token: @refresh_token)
      raise invalid('INVALID_GRANT', 'refresh token 不存在') if row.nil?
      raise invalid('INVALID_GRANT', 'revoked refresh_token') if row.revoked

      scope = OauthAccessToken.find_by(id: row.access_token_id)&.scope
      row.update!(revoked: true)
      issue(row.client_id, row.user_id, row.tenant_id, scope)
    end

    # 新 refresh 落库（"rt_<uuid>" 30 天）+ HS256 access JWT（镜像 persistTokenPair）
    def issue(client_id, user_id, tenant_id, scope)
      _, refresh = persist_token_pair(client_id, user_id, tenant_id, scope)
      {
        access_token: Auth::JwtVerifier.encode({ sub: user_id, tenant_id: tenant_id }),
        refresh_token: refresh,
        token_type: 'Bearer',
        expires_in: ENV.fetch('JWT_TTL_SECONDS').to_i,
        scope: scope.to_s.split(',').join(' '),
        user_id: user_id,
        client_id: client_id,
        tenant_id: tenant_id
      }
    end

    def persist_token_pair(client_id, user_id, tenant_id, scope)
      now = Time.now
      access = OauthAccessToken.create!(
        token_id: "at_#{SecureRandom.uuid}", access_token: 'n/a', client_id: client_id,
        user_id: user_id, tenant_id: tenant_id, scope: scope,
        expires_at: now + 1.hour, revoked: false
      )
      refresh = "rt_#{SecureRandom.uuid}"
      OauthRefreshToken.create!(
        refresh_token: refresh, access_token_id: access.id, client_id: client_id,
        user_id: user_id, tenant_id: tenant_id, expires_at: now + 30.days, revoked: false
      )
      [access, refresh]
    end

    def client_row
      @client_row ||= OauthClient.find_by(client_id: @client_id)
    end

    def invalid(code, message)
      TokenError.new(code, message)
    end

    # token 端点错误码走 body {code: INVALID_*}（springboot 直接 ResponseEntity 的镜像）
    class TokenError < StandardError
      attr_reader :code

      def initialize(code, message)
        super(message)
        @code = code
      end
    end
  end
end
