# frozen_string_literal: true

# 菜单（public.sys_menu）。根 parent_id = 全零 UUID。
class SysMenu < ApplicationRecord
  self.table_name = 'sys_menu'
  # type 列是业务枚举（1/2/3），不是 STI 列
  self.inheritance_column = nil
  ROOT_MENU_ID = '00000000-0000-0000-0000-000000000000'

  has_many :sys_role_menus, foreign_key: :menu_id, primary_key: :id
end
