# frozen_string_literal: true

# 租户缝守卫 —— aspnetcore TenantGuard / springboot SecurityConfig 的 Rails 镜像。
#
# 家族语义（suite-hard-rules §3）：
# - 保护路由挂本 concern（include 即生效，跳过 TenantGuard 禁止）
# - Authorization 缺失/非 Bearer → 401；验签失败/expired → 401（不吞异常，转结构化响应）
# - 验签后暴露 current_tenant_id / current_user_id 供租户过滤；业务身份字段
#   缺失必须 401/403，禁 demo 字面量兜底（ADR-0019）
module TenantGuard
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request!
  end

  private

  def authenticate_request!
    header = request.headers['Authorization'].to_s
    token = header.delete_prefix('Bearer ').strip
    return render_unauthorized('missing bearer token') if token.empty? || header == token

    @auth_payload = Auth::JwtVerifier.new.verify!(token)
  rescue JWT::ExpiredSignature
    render_unauthorized('token expired')
  rescue JWT::DecodeError => e
    render_unauthorized("invalid token: #{e.message}")
  end

  # 租户缝：查询必须用它过滤（where(tenant_id: current_tenant_id)），禁全表泄露
  def current_tenant_id
    @auth_payload&.dig('tenant_id')
  end

  def current_user_id
    @auth_payload&.dig('sub')
  end

  # 租户缝校验（springboot TenantGuard.verifyPathTenant 镜像）：
  # path tenantId 与 JWT tenant_id claim 不等 → 403 FORBIDDEN。
  def verify_path_tenant!
    return if params[:tenant_id].present? && params[:tenant_id] == current_tenant_id

    raise ApplicationController::AccessDenied, 'tenant mismatch'
  end

  # oauth 链的 decode_bearer! 在 ApplicationController（oauth 控制器不挂本 concern）

  def render_unauthorized(message)
    response.set_header('WWW-Authenticate', 'Bearer realm="api"')
    render json: { code: 'INVALID_CREDENTIALS', message: message }, status: :unauthorized
  end
end
