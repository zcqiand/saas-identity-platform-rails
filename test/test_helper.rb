# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

# 家族 harness（trace 适配器）：fn("Mxx.Fxx.Ixx") 登记 + TRACE_MAP=1 时挂 TraceReporter。
# 与 adapters/rails/test/helper.rb 同构 —— 模具与真实仓保持同一套适配器语义。
require_relative 'harness/fn'
Minitest.define_singleton_method(:plugin_trace_map_init) do |*_options|
  next unless ENV['TRACE_MAP'] == '1'

  require_relative 'harness/trace_reporter'
  Minitest.reporter << Harness::TraceReporter.new
end
Minitest.extensions << 'trace_map'

module ActiveSupport
  class TestCase
    # TRACE_MAP=1 时单 worker：多进程会竞写 .state/trace.json（profiles/rails.toml 注释）。
    parallelize(workers: (ENV['TRACE_MAP'] == '1' ? 1 : :number_of_processors), with: :threads)

    # 家族禁 fixtures/*.yml：schema SSOT = shared 仓 drizzle，种子归 shared seed-db.mjs 独占。
    # 测试数据在各自测试内显式造（或后续接 factory），不靠 fixtures 隐式装载。
  end
end
