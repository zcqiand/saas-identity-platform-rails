# frozen_string_literal: true

# /me/menus 装配（springboot MeController.getMyMenus 镜像）：
# member(user, 全量) -> member_role -> role_menu -> sys_menu -> 按 clientId 分组建树。
# EffectiveMenuNode：根 parentId 零值 UUID -> nil；孤儿（parent 不在授权集）提升为 root；
# 仅根层按 sortOrder 升序，子层不再排序。
module Me
  class MenuTree
    ROOT_ID = SysMenu::ROOT_MENU_ID

    def initialize(user_id)
      @user_id = user_id
    end

    # @impl M04.F04.I08 (book anchor xr-know-012)
    def call
      member_ids = TenantMember.where(user_id: @user_id).pluck(:id)
      return {} if member_ids.empty?

      role_ids = TenantMemberRole.where(member_id: member_ids).pluck(:role_id)
      return {} if role_ids.empty?

      menu_ids = SysRoleMenu.where(role_id: role_ids).pluck(:menu_id).uniq
      return {} if menu_ids.empty?

      menus = SysMenu.where(id: menu_ids)
      menus.group_by(&:client_id).transform_values { |rows| build_tree(rows) }
    end

    private

    def build_tree(rows)
      by_id = rows.index_by(&:id)
      nodes = rows.to_h { |m| [m, node_for(m)] }
      roots = []
      rows.each do |m|
        parent = m.parent_id == ROOT_ID ? nil : by_id[m.parent_id]
        if parent.nil?
          roots << nodes[m]
        else
          nodes[parent][:children] << nodes[m]
        end
      end
      roots.sort_by { |n| n[:sort_order] || 0 }
    end

    def node_for(m)
      {
        id: m.id,
        client_id: m.client_id,
        parent_id: m.parent_id == ROOT_ID ? nil : m.parent_id,
        title: m.title,
        type: Family::Dicts.menu_type(m.type),
        path: m.path,
        component: m.component,
        perms: m.perms,
        icon: m.icon,
        sort_order: m.sort_order,
        children: []
      }
    end
  end
end
