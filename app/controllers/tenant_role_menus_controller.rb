# frozen_string_literal: true

# tag: tenant-role-menus -- protected + TenantGuard。
# 聚合视图 RoleMenuGrant：{ roleId, tenantId, menuIds(升序), updatedAt(=sys_role.updated_at) }。
# @impl M00.F04.I01 (book anchor xr-know-012)
class TenantRoleMenusController < ApplicationController
  include TenantGuard

  before_action :verify_path_tenant!

  # clientId 参数被忽略（镜像）
  def list_sys_role_menus
    role = locate_role
    render_camel({
                   role_id: role.id,
                   tenant_id: params[:tenant_id],
                   menu_ids: SysRoleMenu.where(role_id: role.id).order(:menu_id).pluck(:menu_id),
                   updated_at: role.updated_at
                 })
  end

  # 全量替换（差量实现镜像）：锁 role 行 -> 删不在集合的 -> 插缺失（幂等）-> touch role。
  # 响应直接从请求集构造（去重排序），不回读
  # @impl M00.F04.I03 (book anchor xr-know-012)
  def set_sys_role_menus
    role = locate_role
    requested = params[:menuIds].is_a?(Array) ? params[:menuIds].map(&:to_s).uniq.sort : []
    replace_grants(role, requested)
    render_camel({
                   role_id: role.id,
                   tenant_id: params[:tenant_id],
                   menu_ids: requested,
                   updated_at: role.reload.updated_at
                 })
  end

  # bulk 全删；roleId 不存在也 204（不预查，镜像）
  # @impl M00.F04.I04 (book anchor xr-know-012)
  def clear_sys_role_menus
    SysRoleMenu.where(role_id: params[:role_id]).delete_all
    head :no_content
  end

  private

  # 差量实现镜像：锁 role 行 -> 删不在集合的 -> 插缺失（幂等）-> touch role
  def replace_grants(role, requested)
    ActiveRecord::Base.transaction do
      locked = SysRole.lock.find(role.id)
      if requested.empty?
        SysRoleMenu.where(role_id: locked.id).delete_all
      else
        SysRoleMenu.where(role_id: locked.id).where.not(menu_id: requested).delete_all
        requested.each { |menu_id| SysRoleMenu.find_or_create_by!(role_id: locked.id, menu_id: menu_id) }
      end
      locked.touch
    end
  end

  def locate_role
    role = SysRole.find_by!(id: params[:role_id])
    raise ActiveRecord::RecordNotFound, 'role not in tenant' if role.tenant_id != params[:tenant_id]

    role
  end
end
