# frozen_string_literal: true

module Harness
  # fn -> .state/trace.json 的登记表：{ 测试方法名 => { fns:, file: } }。
  #
  # 荣誉契约（与 java-spring 的 @Fn 注解同源，见 adapters/java-spring/README.md）：
  # - 只给「直接验证」的测试挂 ID；间接验证 / 纯工程测试（脚手架冒烟、fixture 自检）不挂
  # - 一个测试 >3 个 ID = 测得太宽，拆
  # - ID 必须已登记在 docs/functions/function-tree.md，否则 L5 报悬空引用
  # - skip 的测试 body 不执行 -> 天然无登记；TraceReporter 对 skipped? 再强制 fns=[]
  #   （双保险：适配器在源头保证「被 skip 仍声称覆盖」结构上不可能）
  FN_REGISTRY = {}.freeze

  # 在测试方法体内调用：fn "M01.F01.I01", "M01.F01.I02"
  # 键用 base_label（Ruby 3.4 起 label 带 "Class#" 前缀，base_label 才是纯方法名）
  def fn(*ids)
    loc = caller_locations(1, 1).first
    FN_REGISTRY[loc.base_label] = { fns: ids.map(&:to_s), file: loc.path }
  end
end

Minitest::Test.include Harness if defined?(Minitest::Test)
