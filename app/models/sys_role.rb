# frozen_string_literal: true

# 租户×client 作用域角色（public.sys_role）。
class SysRole < ApplicationRecord
  self.table_name = 'sys_role'

  has_many :sys_role_menus, foreign_key: :role_id, primary_key: :id
  has_many :tenant_member_roles, foreign_key: :role_id, primary_key: :id
end
