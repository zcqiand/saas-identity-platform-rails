# frozen_string_literal: true

# 租户本地身份（public.tenant_member）。API 用 userId，内部按 (userId, tenant_id) 解析。
class TenantMember < ApplicationRecord
  self.table_name = 'tenant_member'

  belongs_to :tenant, foreign_key: :tenant_id, primary_key: :id
  belongs_to :user, class_name: 'SysUser', foreign_key: :user_id, primary_key: :id
  has_many :tenant_member_roles, foreign_key: :member_id, primary_key: :id
end
