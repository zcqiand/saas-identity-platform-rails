# frozen_string_literal: true

# 家族 CORS 契约：origin 白名单读 SAAS_CORS_ALLOWED_ORIGINS（逗号分隔，值=saas 前端
# dev origin 5101/5102/5103），fail-fast 无默认兜底（suite-hard-rules §1）。
# lab 家族对应键是 LAB_CORS_ALLOWED_ORIGINS（值 5202/5203）—— 键名照抄 springboot 镜像。
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('SAAS_CORS_ALLOWED_ORIGINS').split(',').map(&:strip)
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Authorization]
  end
end
