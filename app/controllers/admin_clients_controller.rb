# frozen_string_literal: true

# tag: admin-clients —— JWT 必需、无租户校验（admin 面 dev 无 scope 区分镜像）。
# 寻址一律 oauth_client.client_id 业务字符串，非行 UUID。
class AdminClientsController < ApplicationController
  include TenantGuard

  # @impl M04.F01.I01 (book anchor xr-know-012)
  def list_clients
    render_paginated(OauthClient.all) { |c| client_dto(c) }
  end

  # 应用层默认：validity 缺省/<=0 -> 3600/86400（不是 DB DEFAULT 7200/2592000，镜像）；
  # 创建类端点 200 非 201（家族口径）
  # @impl M04.F01.I02 (book anchor xr-know-012)
  def create_client
    attrs = create_attrs
    client = OauthClient.new(
      client_id: attrs[:client_id],
      client_name: attrs[:client_name],
      client_secret: attrs[:client_secret],
      grant_types: attrs[:grant_types],
      redirect_uris: attrs[:redirect_uris],
      scopes: attrs[:scopes],
      access_token_validity: positive_or(attrs[:access_token_validity], 3600),
      refresh_token_validity: positive_or(attrs[:refresh_token_validity], 86_400),
      auto_approve: attrs[:auto_approve].to_s == 'true',
      status: 1
    )
    client.save!
    render_camel(client_dto(client))
  end

  # @impl M04.F01.I03 (book anchor xr-know-012)
  def get_client
    render_camel(client_dto(find_client))
  end

  # 镜像 springboot：只应用 clientName/redirectUris/scopes（其余字段忽略）
  # @impl M04.F01.I04 (book anchor xr-know-012)
  def update_client
    client = find_client
    body = params.permit(:clientName, :redirectUris, :scopes)
    updates = body.to_h.slice(:clientName, :redirectUris, :scopes)
                  .transform_keys { |k| k.to_s.underscore }
    client.update!(updates) if updates.any?
    render_camel(client_dto(client))
  end

  # body { status } 可空，null 则不变（镜像）
  # @impl M04.F02.I01 (book anchor xr-know-012)
  def set_client_status
    client = find_client
    client.update!(status: params[:status].to_i) if params.key?(:status) && params[:status].present?
    render_camel(client_dto(client))
  end

  # @impl M04.F01.I05 (book anchor xr-know-012)
  def delete_client
    find_client.destroy!
    head :no_content
  end

  private

  def find_client
    OauthClient.find_by!(client_id: params[:client_id])
  end

  def client_dto(c)
    {
      id: c.id,
      client_id: c.client_id,
      client_name: c.client_name,
      grant_types: c.grant_types,
      redirect_uris: c.redirect_uris,
      scopes: c.scopes,
      access_token_validity: c.access_token_validity,
      refresh_token_validity: c.refresh_token_validity,
      auto_approve: c.auto_approve,
      status: c.status,
      created_at: c.created_at,
      updated_at: c.updated_at
    }
  end

  def create_attrs
    params.permit(:clientId, :clientName, :clientSecret, :grantTypes, :redirectUris,
                  :scopes, :accessTokenValidity, :refreshTokenValidity, :autoApprove)
          .to_h.transform_keys { |k| k.to_s.underscore }.symbolize_keys
  end

  def positive_or(value, default)
    v = value.to_i
    v.positive? ? v : default
  end
end
