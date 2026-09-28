# frozen_string_literal: true

# tag: admin-tenants —— JWT 必需、无租户校验。
class AdminTenantsController < ApplicationController
  include TenantGuard

  def list_tenants
    render_paginated(Tenant.all) { |t| tenant_dto(t) }
  end

  def create_tenant
    raise ArgumentError, 'tenantKey: is required' if params[:tenantKey].blank?
    raise ArgumentError, 'name: is required' if params[:name].blank?

    tenant = Tenant.create!(tenant_key: params[:tenantKey], name: params[:name], status: 1)
    render_camel(tenant_dto(tenant))
  end

  def get_tenant
    render_camel(tenant_dto(find_tenant))
  end

  # status 枚举 active|suspended -> 写库 1|0；读侧 status==1 ? 'active' : 'active' 是
  # springboot toDto 的忠实镜像（无 0 分支，suspended 不可见 —— 已知 quirk，勿修）
  def update_tenant
    tenant = find_tenant
    updates = {}
    updates[:name] = params[:name] if params.key?(:name) && params[:name].present?
    if params.key?(:status) && params[:status].present?
      updates[:status] = params[:status] == 'active' ? 1 : 0
    end
    tenant.update!(updates) if updates.any?
    render_camel(tenant_dto(tenant))
  end

  # 行不存在也 204（不预查，镜像）
  def delete_tenant
    Tenant.where(id: params[:id]).delete_all
    head :no_content
  end

  private

  def find_tenant
    Tenant.find_by!(id: params[:id])
  end

  def tenant_dto(t)
    {
      id: t.id,
      tenant_key: t.tenant_key,
      name: t.name,
      # 恒 'active' 是 springboot toDto 的忠实镜像（无 0 分支，suspended 不可见 —— 已知
      # quirk，勿修；写侧 active->1 其余->0 在 update_tenant）
      status: 'active',
      created_at: t.created_at,
      updated_at: t.updated_at
    }
  end
end
