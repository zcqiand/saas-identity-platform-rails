# frozen_string_literal: true

# tag: auth —— public（/auth/** permitAll 镜像），无 TenantGuard。
class SessionsController < ApplicationController
  rescue_from Auth::LoginService::LockoutError do
    head :locked
  end

  def login
    render_camel Auth::LoginService.new(**login_params).call
  end

  # 204 恒定，无任何 token 撤销副作用（springboot logout 镜像）
  # @impl M01.F04.I06 (book anchor xr-know-012)
  def logout
    head :no_content
  end

  private

  def login_params
    body = params.permit(:username, :password, :clientId)
    %i[username password clientId].each do |key|
      raise ArgumentError, "#{key}: is required" if body[key].blank?
    end
    { username: body[:username], password: body[:password], client_id: body[:clientId] }
  end
end
