# frozen_string_literal: true

# OAuth authorize（springboot OauthController.authorize 镜像）：
# - Bearer 手动 decode（该链无 Jwt principal），无 tenant_id claim -> 401
# - client 不存在 -> 400；redirect 白名单：精确相等 或 前缀+? 边界（子路径不算）
# - code = "ac_<uuid>"，5 分钟过期，落 oauth_code
module Oauth
  class AuthorizeService
    # params 走 camelCase 键（与 TokenService 同款直读 controller params 形态）
    def initialize(params, payload:)
      @client_id = params[:clientId]
      @redirect_uri = params[:redirectUri]
      @response_type = params[:responseType]
      @scope = params[:scope]
      @state = params[:state]
      @payload = payload
    end

    def call
      raise ArgumentError, 'responseType: must be "code"' unless @response_type == 'code'
      raise ArgumentError, "INVALID_CLIENT: unknown clientId #{@client_id}" if client.nil?
      raise ArgumentError, "INVALID_REDIRECT_URI: #{@redirect_uri}" unless redirect_allowed?

      code = "ac_#{SecureRandom.uuid}"
      OauthCode.create!(
        code: code,
        client_id: @client_id,
        user_id: @payload['sub'],
        tenant_id: @payload['tenant_id'],
        redirect_uri: @redirect_uri,
        scope: @scope,
        expires_at: Time.now + 5.minutes
      )
      { code: code, state: @state }
    end

    private

    def client
      @client ||= OauthClient.find_by(client_id: @client_id)
    end

    def redirect_allowed?
      return false if @redirect_uri.blank?

      client.redirect_uris.to_s.split(',').map(&:strip).any? do |allowed|
        @redirect_uri == allowed || (@redirect_uri.start_with?(allowed) && @redirect_uri[allowed.length] == '?')
      end
    end
  end
end
