# frozen_string_literal: true

# tag: client-menus —— protected（非白名单路径）但无 TenantGuard（镜像）。
# get/update/delete 不校验 menu.client_id == path clientId（仅 findById，镜像）。
class ClientMenusController < ApplicationController
  include TenantGuard

  # 扁平列表（非树），parentId 零值 UUID 不转 null，无 updatedAt（镜像 DTO）
  def list_sys_menus
    menus = SysMenu.where(client_id: params[:client_id]).order(:sort_order)
    render_camel(menus.map { |m| menu_dto(m) })
  end

  def create_sys_menu
    body = params.permit(:parentId, :title, :type, :path, :component, :perms, :icon, :sortOrder)
    raise ArgumentError, 'title: is required' if body[:title].blank?

    type_code = body[:type].present? ? Family::Dicts.menu_type_code(body[:type]) : 1
    menu = SysMenu.create!(
      client_id: params[:client_id],
      parent_id: body[:parentId].presence || SysMenu::ROOT_MENU_ID,
      title: body[:title],
      type: type_code,
      path: body[:path],
      component: body[:component],
      perms: body[:perms],
      icon: body[:icon],
      sort_order: body[:sortOrder].to_i,
      status: 1
    )
    render_camel(menu_dto(menu))
  end

  def get_sys_menu
    render_camel(menu_dto(SysMenu.find(params[:menu_id])))
  end

  # 镜像 springboot：只应用 title/path/component/perms/icon/sortOrder（忽略 parentId/type/status）
  def update_sys_menu
    menu = SysMenu.find(params[:menu_id])
    updates = params.permit(:title, :path, :component, :perms, :icon, :sortOrder)
                    .to_h.transform_keys { |k| k.to_s.underscore }
                    .compact
    menu.update!(updates) if updates.any?
    render_camel(menu_dto(menu))
  end

  # body { parentId } 非空则改挂；200 = 菜单 DTO；不存在 404
  def move_sys_menu
    menu = SysMenu.find(params[:menu_id])
    menu.update!(parent_id: params[:parentId]) if params[:parentId].present?
    render_camel(menu_dto(menu))
  end

  # body { orderedMenuIds }：取 indexOf(menuId)，>=0 写 sortOrder=idx（只改当前菜单一条）；
  # 响应 = 该 clientId 全量扁平列表；菜单不存在 404
  def reorder_sys_menus
    menu = SysMenu.find(params[:menu_id])
    ordered = params[:orderedMenuIds]
    raise ArgumentError, 'orderedMenuIds: is required' unless ordered.is_a?(Array)

    idx = ordered.index(menu.id)
    menu.update!(sort_order: idx) if idx
    render_camel(
      SysMenu.where(client_id: params[:client_id]).order(:sort_order).map { |m| menu_dto(m) }
    )
  end

  # deleteById 语义：不预查，恒 204
  def delete_sys_menu
    SysMenu.where(id: params[:menu_id]).delete_all
    head :no_content
  end

  private

  def menu_dto(m)
    {
      id: m.id,
      client_id: m.client_id,
      parent_id: m.parent_id,
      title: m.title,
      type: Family::Dicts.menu_type(m.type),
      path: m.path,
      component: m.component,
      perms: m.perms,
      icon: m.icon,
      sort_order: m.sort_order,
      status: m.status,
      created_at: m.created_at
    }
  end
end
