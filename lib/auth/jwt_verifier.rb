# frozen_string_literal: true

require 'jwt'

module Auth
  # 家族 JWT 验签（HS256）—— springboot JwtIssuer / aspnetcore JwtBearer 的 Ruby 镜像。
  # 同一 JWT_SIGNING_KEY / JWT_ISSUER / JWT_AUDIENCE，payload {sub, tenant_id, iss, aud, exp}。
  # fail-fast：任一 env 缺失直接 KeyError，禁默认兜底（suite-hard-rules §1）；
  # 身份字段缺失必须 401（ADR-0019 / suite-hard-rules §3，禁 demo 字面量兜底）。
  class JwtVerifier
    def initialize(
      signing_key: ENV.fetch('JWT_SIGNING_KEY'),
      issuer: ENV.fetch('JWT_ISSUER'),
      audience: ENV.fetch('JWT_AUDIENCE')
    )
      @signing_key = signing_key
      @issuer = issuer
      @audience = audience
    end

    # 验签 + 标准校验（exp/iss/aud）。无效抛 JWT::ExpiredSignature / JWT::InvalidIssuerError 等，
    # 由调用方（TenantGuard）统一转 401 —— 禁 rescue 后吞异常（profiles/rails.toml forbid）。
    # 返回 payload（sub / tenant_id / ...）。
    def verify!(token)
      decoded, = JWT.decode(
        token, @signing_key, true,
        algorithm: 'HS256', iss: @issuer, aud: @audience,
        verify_expiration: true, verify_iss: true, verify_aud: true
      )
      decoded
    end

    # 测试助手：按家族 payload 形状签发 token（仅 test 链用；生产 token 由 springboot IdP 签）。
    def self.encode(payload, ttl: ENV.fetch('JWT_TTL_SECONDS').to_i)
      now = Time.now.to_i
      JWT.encode(
        { **payload, iat: now, exp: now + ttl,
                     iss: ENV.fetch('JWT_ISSUER'), aud: ENV.fetch('JWT_AUDIENCE') },
        ENV.fetch('JWT_SIGNING_KEY'), 'HS256'
      )
    end
  end
end
