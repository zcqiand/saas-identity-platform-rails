# frozen_string_literal: true

# OAuth client = 应用本体（public.oauth_client）。寻址用 clientId 字符串，不是行 UUID。
class OauthClient < ApplicationRecord
  self.table_name = 'oauth_client'

  has_many :tenant_applications, foreign_key: :client_id, primary_key: :client_id
  has_many :sys_menus, foreign_key: :client_id, primary_key: :client_id
  has_many :sys_roles, foreign_key: :client_id, primary_key: :client_id
end
