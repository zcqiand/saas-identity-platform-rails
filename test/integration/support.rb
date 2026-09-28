# frozen_string_literal: true

# 集成测试共享助手：真库链（saas_test），事务回滚保种子（AC 程序化，无 fixtures）。
module IntegrationSupport
  DEV_USER = 'alice'
  DEV_PASSWORD = 'dev123456'
  DEV_CLIENT = 'saas-console'

  def login(username: DEV_USER, password: DEV_PASSWORD, client_id: DEV_CLIENT)
    post '/api/v1/auth/login', params: { username: username, password: password, clientId: client_id }, as: :json
    response.body.present? ? JSON.parse(response.body) : {}
  end

  def auth_header(token)
    { 'Authorization' => "Bearer #{token}" }
  end

  def alice_tenant_id
    TenantMember.where(user_id: SysUser.find_by!(username: DEV_USER).id, status: 1)
                .order(:created_at).first!.tenant_id
  end
end
