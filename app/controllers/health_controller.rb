# frozen_string_literal: true

# 家族健康探针（contract-test start-family.sh healthcheck 目标）。
# 不挂鉴权；只证明进程活着。DB 探活由 gate L4 真库链负责（fail-not-skip）。
class HealthController < ActionController::API
  def show
    render json: { status: 'ok', stack: 'rails', family: 'saas' }
  end
end
