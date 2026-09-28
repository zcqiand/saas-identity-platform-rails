# frozen_string_literal: true

# 租户应用订阅（public.tenant_application）。
class TenantApplication < ApplicationRecord
  self.table_name = 'tenant_application'

  belongs_to :tenant, foreign_key: :tenant_id, primary_key: :id
end
