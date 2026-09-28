# frozen_string_literal: true

# 路由面 = lib/generated/api_manifest.json 的 1:1 镜像（SSOT 是 shared openapi.yaml）。
# action 名 = operationId 后半段 underscore；test/contracts/route_parity_test.rb 逐条对账。
Rails.application.routes.draw do
  get '/health', to: 'health#show'

  scope '/api/v1', defaults: { format: :json } do
    # tag: admin-clients（平台管理面，:clientId 是 oauth_client.client_id 字符串）
    get    '/admin/clients',              to: 'admin_clients#list_clients'
    post   '/admin/clients',              to: 'admin_clients#create_client'
    get    '/admin/clients/:client_id',   to: 'admin_clients#get_client'
    patch  '/admin/clients/:client_id',   to: 'admin_clients#update_client'
    patch  '/admin/clients/:client_id/status', to: 'admin_clients#set_client_status'
    delete '/admin/clients/:client_id', to: 'admin_clients#delete_client'

    # tag: admin-tenants（平台管理面，:id 是行 UUID）
    get    '/admin/tenants',      to: 'admin_tenants#list_tenants'
    post   '/admin/tenants',      to: 'admin_tenants#create_tenant'
    get    '/admin/tenants/:id',  to: 'admin_tenants#get_tenant'
    patch  '/admin/tenants/:id',  to: 'admin_tenants#update_tenant'
    delete '/admin/tenants/:id',  to: 'admin_tenants#delete_tenant'

    # tag: auth
    post '/auth/login',  to: 'sessions#login'
    post '/auth/logout', to: 'sessions#logout'

    # tag: clients
    get '/clients/:client_id', to: 'clients#get_client'

    # tag: client-menus
    get    '/clients/:client_id/menus',                 to: 'client_menus#list_sys_menus'
    post   '/clients/:client_id/menus',                 to: 'client_menus#create_sys_menu'
    get    '/clients/:client_id/menus/:menu_id',        to: 'client_menus#get_sys_menu'
    patch  '/clients/:client_id/menus/:menu_id',        to: 'client_menus#update_sys_menu'
    patch  '/clients/:client_id/menus/:menu_id/parent', to: 'client_menus#move_sys_menu'
    put    '/clients/:client_id/menus/:menu_id/reorder', to: 'client_menus#reorder_sys_menus'
    delete '/clients/:client_id/menus/:menu_id', to: 'client_menus#delete_sys_menu'

    # tag: me
    get  '/me',                        to: 'me#whoami'
    get  '/me/menus',                  to: 'me#get_my_menus'
    get  '/me/tenants',                to: 'me#list_my_tenants'
    post '/me/tenants/:tenant_id/switch', to: 'me#switch_tenant'

    # tag: oauth
    post '/oauth/authorize', to: 'oauth#authorize'
    post '/oauth/token',     to: 'oauth#token'

    # tag: tenant-applications
    get    '/tenants/:tenant_id/applications',                to: 'tenant_applications#list_tenant_applications'
    post   '/tenants/:tenant_id/applications',                to: 'tenant_applications#subscribe_tenant_application'
    patch  '/tenants/:tenant_id/applications/:client_id',     to: 'tenant_applications#update_tenant_application'
    delete '/tenants/:tenant_id/applications/:client_id',     to: 'tenant_applications#remove_tenant_application'

    # tag: tenant-members
    get    '/tenants/:tenant_id/members',                    to: 'tenant_members#list_tenant_users'
    post   '/tenants/:tenant_id/members',                    to: 'tenant_members#create_tenant_user'
    post   '/tenants/:tenant_id/members/invitations',        to: 'tenant_members#invite_tenant_user'
    get    '/tenants/:tenant_id/members/:user_id',           to: 'tenant_members#get_tenant_user'
    patch  '/tenants/:tenant_id/members/:user_id',           to: 'tenant_members#update_tenant_user'
    patch  '/tenants/:tenant_id/members/:user_id/status',    to: 'tenant_members#change_tenant_user_status'
    put    '/tenants/:tenant_id/members/:user_id/roles',     to: 'tenant_members#assign_tenant_member_roles'
    delete '/tenants/:tenant_id/members/:user_id',           to: 'tenant_members#delete_tenant_user'

    # tag: tenant-role-menus
    get    '/tenants/:tenant_id/roles/:role_id/menus', to: 'tenant_role_menus#list_sys_role_menus'
    put    '/tenants/:tenant_id/roles/:role_id/menus', to: 'tenant_role_menus#set_sys_role_menus'
    delete '/tenants/:tenant_id/roles/:role_id/menus', to: 'tenant_role_menus#clear_sys_role_menus'

    # tag: tenant-roles
    get    '/tenants/:tenant_id/roles',        to: 'tenant_roles#list_sys_roles'
    post   '/tenants/:tenant_id/roles',        to: 'tenant_roles#create_sys_role'
    get    '/tenants/:tenant_id/roles/:role_id', to: 'tenant_roles#get_sys_role'
    patch  '/tenants/:tenant_id/roles/:role_id', to: 'tenant_roles#update_sys_role'
    delete '/tenants/:tenant_id/roles/:role_id', to: 'tenant_roles#delete_sys_role'
  end
end
