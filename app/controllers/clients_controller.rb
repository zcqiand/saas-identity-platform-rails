# frozen_string_literal: true

# tag: clients —— 匿名可读（/api/v1/clients/单段 在 SecurityConfig 白名单的镜像）。
class ClientsController < ApplicationController
  # @impl M04.F01.I06 (book anchor xr-know-012)
  def get_client
    client = OauthClient.find_by!(client_id: params[:client_id])
    render_camel({
                   client_id: client.client_id,
                   client_name: client.client_name,
                   status: client.status
                 })
  end
end
