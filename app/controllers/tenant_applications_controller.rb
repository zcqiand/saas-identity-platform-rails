# frozen_string_literal: true

# tag: tenant-applications —— protected + TenantGuard（租户缝）。
class TenantApplicationsController < ApplicationController
  include TenantGuard

  before_action :verify_path_tenant!

  # @impl M00.F05.I01 (book anchor xr-know-012)
  def list_tenant_applications
    scope = TenantApplication.where(tenant_id: params[:tenant_id])
    render_paginated(scope) { |a| app_dto(a) }
  end

  # 未知 clientId -> 404（先查 oauth_client，非盲插）；expireTime 落库（2026-10-03 镜像追平
  # springboot 01704a2——旧「不落库（镜像）」是对修复前行为的镜像，已陈旧）；
  # dup 预检 → 400 clean message（此前盲插 RecordNotUnique → 驱动诊断泄漏，CT 同批断言）
  # @impl M00.F05.I02 (book anchor xr-know-012)
  def subscribe_tenant_application
    ensure_subscribable!
    app = TenantApplication.create!(
      tenant_id: params[:tenant_id], client_id: params[:clientId], status: 1,
      expire_time: params[:expireTime]
    )
    render_camel(app_dto(app))
  end

  # @impl M00.F05.I03 (book anchor xr-know-012)
  def update_tenant_application
    app = find_app
    updates = {}
    updates[:status] = params[:status].to_i if params.key?(:status) && params[:status].present?
    updates[:expire_time] = params[:expireTime] if params.key?(:expireTime) && params[:expireTime].present?
    app.update!(updates) if updates.any?
    render_camel(app_dto(app))
  end

  # 行不存在也 204（ifPresent 静默，镜像）
  # @impl M00.F05.I04 (book anchor xr-know-012)
  def remove_tenant_application
    TenantApplication.where(tenant_id: params[:tenant_id], client_id: params[:client_id]).delete_all
    head :no_content
  end

  private

  # 2026-10-03 订阅前校验链抽方法（rubocop AbcSize）：未知 clientId → 404（非盲插）、
  # 空 clientId → 400、dup 预检 → 400 clean message（不泄漏驱动诊断，CT I75 同批断言）。
  def ensure_subscribable!
    OauthClient.find_by!(client_id: params[:clientId])
    raise ArgumentError, 'clientId: is required' if params[:clientId].blank?

    return unless TenantApplication.exists?(tenant_id: params[:tenant_id], client_id: params[:clientId])

    raise ArgumentError,
          "subscription already exists: tenant=#{params[:tenant_id]} client=#{params[:clientId]}"
  end

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
