# frozen_string_literal: true

# 成员-角色绑定（public.tenant_member_role，复合主键）。
class TenantMemberRole < ApplicationRecord
  self.table_name = 'tenant_member_role'
end
