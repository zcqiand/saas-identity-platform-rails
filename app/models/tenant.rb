# frozen_string_literal: true

# 租户（public.tenant）。status：1=active / 0=disabled。
class Tenant < ApplicationRecord
  self.table_name = 'tenant'

  has_many :tenant_members, foreign_key: :tenant_id, primary_key: :id
  has_many :tenant_applications, foreign_key: :tenant_id, primary_key: :id
  has_many :sys_roles, foreign_key: :tenant_id, primary_key: :id
end
