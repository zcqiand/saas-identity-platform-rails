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
  # 登记表按测试运行时逐条写入，冻结会让 fn() 结构上不可用（REQ-2026-022 首次启用即
  # FrozenError 实证）；rubocop 宽免仅限本行。
  # rubocop:disable-next Style/MutableConstant
  FN_REGISTRY = {}

  # 在测试方法体内调用：fn "M01.F01.I01", "M01.F01.I02"
  # 键必须与 reporter 侧 result.name 对齐：测试实例自身的 name（方法名形态）。
  # base_label 不可用——define_method 块帧在 Ruby 3.4 + minitest 5.25 下返回 "run"
  # （REQ-2026-022 探针实证），直接登记会全部互覆且 reporter 查空。
  def fn(*ids)
    loc = caller_locations(1, 1).first
    key = name if respond_to?(:name) && name
    key ||= loc.base_label
    FN_REGISTRY[key] = { fns: ids.map(&:to_s), file: loc.path }
  end
end

Minitest::Test.include Harness if defined?(Minitest::Test)
