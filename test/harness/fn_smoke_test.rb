# frozen_string_literal: true

require_relative '../test_helper'

# 锚点适配器冒烟测试 —— 镜像 java-spring 的 FnAnnotationSmokeTest。
#
# 这里刻意不写任何功能 ID 字面：本文件会进每一个新仓的 trace，
# 假 ID 会在 L5 变成悬空引用（同 design-map 备注列 ID 字面之坑）。
# fn() -> trace 的登记映射由 suite 侧模具冒烟（scratch 临时用例）覆盖，不入仓。
class FnSmokeTest < Minitest::Test
  def test_non_inert_test_reports_with_empty_fns
    assert true
  end

  def test_skipped_test_is_inert
    skip '惰性锚点：skip 测试 body 不执行 -> 天然无 fn 登记；reporter 对 skipped? 再强制 fns=[]'
  end
end
