# frozen_string_literal: true

# 登录语义（springboot AuthController.login 镜像，M01.F04）：
# - 未知用户与错密码同 401 INVALID_CREDENTIALS（不泄露存在性）
# - 密码校验：DB 值 "plain:{password}" 前缀直等，否则 BCrypt
# - 连续失败 LOCKOUT_THRESHOLD 次 -> locked_until = now + LOCKOUT_MINUTES -> 423（空响应体）
# - tenantId = 首个 active(status=1) membership 且 tenant 本身 active，否则 403
# - availableTenants：active memberships；clientId 有订阅集则过滤到订阅内，订阅集空则不过滤
module Auth
  class LoginService
    def initialize(username:, password:, client_id:)
      @username = username
      @password = password
      @client_id = client_id
    end

    def call
      user = verify_credentials
      user.update!(failed_attempts: 0, locked_until: nil)
      # 租户先解析（镜像 springboot AuthController.login 顺序：tenant check → persist 内验 clientId）
      tenant_id = current_tenant_id(user)
      raise ArgumentError, 'unknown clientId' if OauthClient.find_by(client_id: @client_id).nil?

      persist_token_pair(user, tenant_id)
      login_payload(user, tenant_id)
    end

    # 423 空响应体（springboot body(null) 忠实镜像，空体即契约形状）
    class LockoutError < StandardError; end

    private

    def verify_credentials
      user = SysUser.find_by(username: @username)
      raise ApplicationController::InvalidCredentials, 'invalid credentials' if user.nil?
      raise LockoutError if user.locked_until.present? && user.locked_until > Time.now

      return user if user.password_matches?(@password)

      register_failure(user)
      raise ApplicationController::InvalidCredentials, 'invalid credentials'
    end

    def login_payload(user, tenant_id)
      {
        user: { id: user.id, username: user.username, email: user.email },
        user_id: user.id,
        current_tenant_id: tenant_id,
        access_token: access_token(user, tenant_id),
        refresh_token: @refresh_token,
        token_type: 'Bearer',
        expires_in: ENV.fetch('JWT_TTL_SECONDS').to_i,
        client_id: @client_id,
        available_tenants: available_tenants(user)
      }
    end

    def register_failure(user)
      attempts = user.failed_attempts.to_i + 1
      locked = attempts >= SysUser::LOCKOUT_THRESHOLD
      user.update!(
        failed_attempts: attempts,
        locked_until: (locked ? Time.now + SysUser::LOCKOUT_MINUTES.minutes : nil)
      )
    end

    def current_tenant_id(user)
      member = TenantMember.where(user_id: user.id, status: 1).order(:created_at).first
      # 家族真源：无 active membership → 403（springboot AuthController AccessDeniedException），
      # 禁止 return nil 兜底（runtime-identity-fallback 禁令）。
      raise ApplicationController::AccessDenied, 'no active tenant membership' if member.nil?

      return member.tenant_id if Tenant.find_by(id: member.tenant_id)&.status == 1

      raise ApplicationController::AccessDenied, 'no active tenant'
    end

    def available_tenants(user)
      members = TenantMember.where(user_id: user.id, status: 1)
      subscribed = TenantApplication.where(client_id: @client_id).pluck(:tenant_id)
      members = members.where(tenant_id: subscribed) if subscribed.any?
      members.order(:created_at).map { |m| Family::MemberViews.membership(m) }
    end

    # 落库 token 对（镜像 springboot persistTokenPair）：access 行 access_token="n/a"，
    # refresh 行 "rt_<uuid>" 30 天，两行都带 tenantId（refresh rotate 继承 → I28 响应
    # 必有 tenantId；漏写 = normalize 剔 nil 后四方比对分叉）
    def persist_token_pair(user, tenant_id)
      now = Time.now
      token = OauthAccessToken.create!(
        token_id: "at_#{SecureRandom.uuid}",
        access_token: 'n/a',
        client_id: @client_id,
        user_id: user.id,
        tenant_id: tenant_id,
        expires_at: now + 1.hour,
        revoked: false
      )
      @refresh_token = "rt_#{SecureRandom.uuid}"
      OauthRefreshToken.create!(refresh_attrs(token, tenant_id, now))
    rescue ActiveRecord::InvalidForeignKey
      raise ArgumentError, 'unknown clientId'
    end

    def refresh_attrs(token, tenant_id, now)
      {
        refresh_token: @refresh_token,
        access_token_id: token.id,
        client_id: @client_id,
        user_id: token.user_id,
        tenant_id: tenant_id,
        expires_at: now + 30.days,
        revoked: false
      }
    end

    def access_token(user, tenant_id)
      Auth::JwtVerifier.encode({ sub: user.id, tenant_id: tenant_id })
    end
  end
end
