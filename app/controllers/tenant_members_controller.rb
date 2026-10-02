# frozen_string_literal: true

# tag: tenant-members -- protected + TenantGuard。寻址：path {userId} = sys_user.id，
# 经 (tenant_id, user_id) 找 member 行，寻不到 404。视图 status 读 member 行。
class TenantMembersController < ApplicationController
  include TenantGuard

  before_action :verify_path_tenant!

  # status query 过滤 DB 级（total=过滤后计数）；排序 createdAt DESC, id ASC；
  # member 无对应 user 行的条目被滤掉
  # @impl M00.F02.I01 (book anchor xr-know-012)
  def list_tenant_users
    scope = filtered_member_scope
    page, page_size = page_params
    total = scope.count
    render_camel({ items: member_items(scope, page, page_size), page: page, page_size: page_size, total: total })
  end

  # @impl M00.F02.I02 (book anchor xr-know-012)
  def create_tenant_user
    body = params.permit(:username, :password, :email, :mobile)
    %i[username password email].each do |key|
      raise ArgumentError, "#{key}: is required" if body[key].blank?
    end
    # 镜像 CreateSysUserRequest.password @Size(min=8, max=256)（shared 契约
    # minLength/maxLength；springboot MethodArgumentNotValidException → 400 同语义）
    if body[:password].length < 8 || body[:password].length > 256
      raise ArgumentError,
            'password: size must be between 8 and 256'
    end

    user = SysUser.create!(
      username: body[:username], password: "plain:#{body[:password]}",
      email: body[:email], mobile: body[:mobile], status: 1, failed_attempts: 0
    )
    member = TenantMember.create!(
      tenant_id: params[:tenant_id], user_id: user.id,
      member_name: body[:username], is_owner: false, status: 1
    )
    render_camel(Family::MemberViews.flat_user_view(member, user))
  end

  # @impl M00.F02.I03 (book anchor xr-know-012)
  def get_tenant_user
    member, user = locate_member
    render_camel(Family::MemberViews.flat_user_view(member, user))
  end

  # 镜像：契约已删 status 字段（状态唯一通道是 /status 端点）；只更新 user 行 email/mobile
  # @impl M00.F02.I04 (book anchor xr-know-012)
  def update_tenant_user
    member, user = locate_member
    updates = params.permit(:email, :mobile).to_h.compact
    user.update!(updates) if updates.any?
    render_camel(Family::MemberViews.flat_user_view(member, user))
  end

  # 删 member_role 绑定 + member 行；user 行不删；204
  # @impl M00.F02.I05 (book anchor xr-know-012)
  def delete_tenant_user
    member, = locate_member
    TenantMemberRole.where(member_id: member.id).delete_all
    member.destroy!
    head :no_content
  end

  # 双写：member.status 与 sys_user.status 同值（家族口径）
  # @impl M00.F02.I08 (book anchor xr-know-012)
  def change_tenant_user_status
    member, user = locate_member
    status_code = Family::Dicts.member_status_code(params.require(:status))
    member.update!(status: status_code)
    user.update!(status: status_code)
    render_camel(Family::MemberViews.flat_user_view(member, user))
  end

  # body { roleIds }：先全删再插；只接受本租户 sys_role 的 roleId，外来/未知静默忽略
  # @impl M01.F02.I01 (book anchor xr-know-012)
  def assign_tenant_member_roles
    member, user = locate_member
    role_ids = params[:roleIds].is_a?(Array) ? params[:roleIds] : []
    valid_ids = SysRole.where(tenant_id: params[:tenant_id], id: role_ids).pluck(:id)
    TenantMemberRole.where(member_id: member.id).delete_all
    valid_ids.each { |rid| TenantMemberRole.create!(member_id: member.id, role_id: rid) }
    render_camel(Family::MemberViews.flat_user_view(member, user))
  end

  # invitations：email 空 -> 400；建真 sys_user（username=email, password 为空串, status=2）；
  # member status=1(active)；响应嵌套视图
  # @impl M00.F02.I06 (book anchor xr-know-012)
  def invite_tenant_user
    email = params[:email].to_s.strip
    raise ArgumentError, 'email: is required' if email.empty?

    user = SysUser.create!(username: email, password: '', email: email, status: 2, failed_attempts: 0)
    member = TenantMember.create!(
      tenant_id: params[:tenant_id], user_id: user.id,
      member_name: email, is_owner: false, status: 1
    )
    render_camel(Family::MemberViews.nested_view(member, user))
  end

  private

  def filtered_member_scope
    scope = TenantMember.where(tenant_id: params[:tenant_id])
    scope = scope.where(status: Family::Dicts.member_status_code(params[:status])) if params[:status].present?
    scope.order(created_at: :desc, id: :asc)
  end

  # 批量取 user 防 N+1；member 无对应 user 行的条目被滤掉
  def member_items(scope, page, page_size)
    window = scope.limit(page_size).offset(page * page_size)
    users = SysUser.where(id: window.pluck(:user_id)).index_by(&:id)
    window.filter_map { |m| users[m.user_id] && Family::MemberViews.flat_user_view(m, users[m.user_id]) }
  end

  def locate_member
    member = TenantMember.find_by!(tenant_id: params[:tenant_id], user_id: params[:user_id])
    user = SysUser.find_by(id: member.user_id)
    raise ActiveRecord::RecordNotFound, 'member user missing' if user.nil?

    [member, user]
  end
end
