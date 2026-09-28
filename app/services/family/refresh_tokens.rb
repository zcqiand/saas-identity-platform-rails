# frozen_string_literal: true

# switch 端点的临时 refresh 形状（springboot JwtIssuer.generateRefreshToken 镜像）。
# "saas-rt-{userId}-{ts-ms}-{rand}"；不落库不持久化 refresh 行。
module Family
  module RefreshTokens
    module_function

    def ephemeral(user_id)
      rand = SecureRandom.base64(24).tr('+/', '-_').delete('=')
      "saas-rt-#{user_id}-#{(Time.now.to_f * 1000).to_i}-#{rand}"
    end
  end
end
