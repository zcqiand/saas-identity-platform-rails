# frozen_string_literal: true

# tag: tenant-applications —— protected + TenantGuard（租户缝）。
class TenantApplicationsController < ApplicationController
  include TenantGuard

  before_action :verify_path_tenant!

  def list_tenant_applications
    scope = TenantApplication.where(tenant_id: params[:tenant_id])
    render_paginated(scope) { |a| app_dto(a) }
  end

  # 未知 clientId -> 404（先查 oauth_client，非盲插）；expireTime 请求字段存在但不落库（镜像）
  def subscribe_tenant_application
    OauthClient.find_by!(client_id: params[:clientId])
    raise ArgumentError, 'clientId: is required' if params[:clientId].blank?

    app = TenantApplication.create!(tenant_id: params[:tenant_id], client_id: params[:clientId], status: 1)
    render_camel(app_dto(app))
  end

  def update_tenant_application
    app = find_app
    updates = {}
    updates[:status] = params[:status].to_i if params.key?(:status) && params[:status].present?
    updates[:expire_time] = params[:expireTime] if params.key?(:expireTime) && params[:expireTime].present?
    app.update!(updates) if updates.any?
    render_camel(app_dto(app))
  end

  # 行不存在也 204（ifPresent 静默，镜像）
  def remove_tenant_application
    TenantApplication.where(tenant_id: params[:tenant_id], client_id: params[:client_id]).delete_all
    head :no_content
  end

  private

  def find_app
    TenantApplication.find_by!(tenant_id: params[:tenant_id], client_id: params[:client_id])
  end

  def app_dto(a)
    {
      id: a.id,
      tenant_id: a.tenant_id,
      client_id: a.client_id,
      status: a.status,
      expire_time: a.expire_time,
      created_at: a.created_at
    }
  end
end
