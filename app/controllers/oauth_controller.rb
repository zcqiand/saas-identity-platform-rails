# frozen_string_literal: true

# tag: oauth —— SecurityConfig 独立 permitAll 链镜像：无 TenantGuard，
# 业务层手动 decode Bearer（authorize），token 端点匿名。
class OauthController < ApplicationController
  rescue_from Oauth::TokenService::TokenError do |e|
    render json: { code: e.code, message: e.message }, status: :bad_request
  end

  def authorize
    payload = decode_bearer!
    result = Oauth::AuthorizeService.new(params, payload: payload).call
    render_camel(result)
  end

  def token
    render_camel(Oauth::TokenService.new(params).call)
  end
end
