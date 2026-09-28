# frozen_string_literal: true

Rails.application.routes.draw do
  # 健康探针：contract-test start-family.sh healthcheck 目标（Stage C3 接线）。
  # 家族禁 rails 自带 /up —— route_parity_test 对「多出来的路由」也红，/health 是唯一 allowlist。
  get '/health', to: 'health#show'
end
