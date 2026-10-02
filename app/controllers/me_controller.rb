# frozen_string_literal: true

# tag: me —— protected（JWT）。userId 取 JWT sub；防御分支无身份回空集（镜像）。
class MeController < ApplicationController
  include TenantGuard

  def whoami
    user = SysUser.find_by(id: current_user_id)
    return render_camel({ memberships: [] }) if user.nil?

    render_camel({
                   id: user.id,
                   email: user.email,
                   memberships: Family::MemberViews.memberships_for(user.id),
                   current_tenant_id: resolved_tenant_id
                 })
  end

  # clientId 参数被忽略（镜像）；active memberships 裸数组
  # @impl M01.F03.I01 (book anchor xr-know-012)
  def list_my_tenants
    members = TenantMember.where(user_id: current_user_id, status: 1).order(:created_at)
    render_camel(members.map { |m| Family::MemberViews.membership(m) })
  end

  def get_my_menus
    render_camel(Me::MenuTree.new(current_user_id).call)
  end

  # switch：tenant 存在 -> 404；member.status != 0（invited/suspended 可切）否则 404。
  # 新 JWT 换 tenant_id；refresh "saas-rt-..." 不落库（镜像 JwtIssuer.generateRefreshToken）
  # @impl M01.F03.I02 (book anchor xr-know-012)
  def switch_tenant
    tenant = Tenant.find_by(id: params[:tenant_id])
    raise ActiveRecord::RecordNotFound, 'tenant not found' if tenant.nil?

    member = TenantMember.find_by(user_id: current_user_id, tenant_id: tenant.id)
    raise ActiveRecord::RecordNotFound, 'membership not found' if member.nil? || member.status.zero?

    token = Auth::JwtVerifier.encode({ sub: current_user_id, tenant_id: tenant.id })
    render_camel({
                   access_token: token,
                   refresh_token: Family::RefreshTokens.ephemeral(current_user_id),
                   expires_at: Time.now + ENV.fetch('JWT_TTL_SECONDS').to_i,
                   tenant_id: tenant.id
                 })
  end

  private

  def resolved_tenant_id
    return current_tenant_id if current_tenant_id.present?

    TenantMember.where(user_id: current_user_id).order(:created_at).first&.tenant_id
  end
end
