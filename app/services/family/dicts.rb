# frozen_string_literal: true

# 家族字典：smallint 枚举 <-> API 字符串（镜像 springboot 各 assembler 的映射分支）。
module Family
  module Dicts
    module_function

    # tenant_member.status：1=active 2=invited 3=suspended 其余/null=disabled
    def member_status(v)
      { 1 => 'active', 2 => 'invited', 3 => 'suspended' }.fetch(v.to_i, 'disabled')
    end

    def member_status_code(str)
      { 'active' => 1, 'invited' => 2, 'suspended' => 3 }.fetch(str, 0)
    end

    # sys_user.status（invitations / members 视图）：无 suspended 档
    def user_status(v)
      { 1 => 'active', 2 => 'invited' }.fetch(v.to_i, 'disabled')
    end

    # sys_menu.type：1=directory 2=menu 3=button，未知->menu
    def menu_type(v)
      { 1 => 'directory', 2 => 'menu', 3 => 'button' }.fetch(v.to_i, 'menu')
    end

    def menu_type_code(str)
      { 'directory' => 1, 'menu' => 2, 'button' => 3 }.fetch(str) do
        raise ArgumentError, 'type: must be one of directory/menu/button'
      end
    end
  end
end
