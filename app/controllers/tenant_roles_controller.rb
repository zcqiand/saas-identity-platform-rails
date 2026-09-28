# frozen_string_literal: true

# tag: tenant-roles -- protected + TenantGuard。role.tenant_id != path tenantId -> 404
# （不泄露跨租户存在性）。
class TenantRolesController < ApplicationController
  include TenantGuard

  before_action :verify_path_tenant!

  # clientId 参数被忽略（镜像）
  def list_sys_roles
    render_paginated(SysRole.where(tenant_id: params[:tenant_id])) { |r| role_dto(r) }
  end

  def create_sys_role
    %i[clientId roleCode roleName].each do |key|
      raise ArgumentError, "#{key}: is required" if params[key].blank?
    end

    role = SysRole.create!(
      tenant_id: params[:tenant_id],
      client_id: params[:clientId],
      role_code: params[:roleCode],
      role_name: params[:roleName],
      description: params[:description],
      is_preset: params[:isPreset].to_s == 'true',
      status: 1
    )
    render_camel(role_dto(role))
  end

  def get_sys_role
    render_camel(role_dto(locate_role))
  end

  # 镜像：只应用 roleName/description（status 字段可空不应用）
  def update_sys_role
    role = locate_role
    updates = params.permit(:roleName, :description).to_h
                    .transform_keys { |k| k.to_s.underscore }.compact
    role.update!(updates) if updates.any?
    render_camel(role_dto(role))
  end

  def delete_sys_role
    role = locate_role
    SysRoleMenu.where(role_id: role.id).delete_all
    TenantMemberRole.where(role_id: role.id).delete_all
    role.destroy!
    head :no_content
  end

  private

  def locate_role
    role = SysRole.find_by!(id: params[:role_id])
    raise ActiveRecord::RecordNotFound, 'role not in tenant' if role.tenant_id != params[:tenant_id]

    role
  end

  def role_dto(r)
    {
      id: r.id,
      tenant_id: r.tenant_id,
      client_id: r.client_id,
      role_code: r.role_code,
      role_name: r.role_name,
      description: r.description,
      is_preset: r.is_preset,
      status: r.status,
      created_at: r.created_at,
      updated_at: r.updated_at
    }
  end
end
