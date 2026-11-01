# frozen_string_literal: true

require_relative '../test_helper'
require_relative 'support'

# 5.121 家族裁定：菜单列表确定性——sortOrder 主键 + id 次级键。
# 乱序插入钉主键；8 条并列 sortOrder 钉次级键（修前 order(:sort_order) 单键下
# 并列行序由 PG heap 决定，插入序 == id 升序概率 1/8!，红是确定的）。
# list 与 reorder 响应同走 order(:sort_order)，两面同钉。
class ClientMenusOrderingTest < ActionDispatch::IntegrationTest
  include IntegrationSupport

  def setup
    @token = login['accessToken']
    @base = '/api/v1/clients/saas-console/menus'
  end

  test 'list and reorder order by sort_order then id' do
    fn 'M04.F04.I01'

    late = create_menu('次', 1)
    early = create_menu('首', 2)
    tied = Array.new(8) { |i| create_menu("并列#{i}", 5) }

    get @base, headers: auth_header(@token)
    assert_equal 200, response.status
    ids = JSON.parse(response.body).map { |m| m['id'] }

    # 主键：sortOrder 升序（1 在 2 前）
    assert_operator ids.index(late), :<, ids.index(early), 'sortOrder=1 应排在 2 前'
    # 次级键：响应中并列组子序列（保持响应序）== id 升序
    assert_equal tied.sort, ids.select { |id| tied.include?(id) }, '并列组应按 id 升序'

    # reorder 响应同面：并列组子序列仍 id 升序
    put "#{@base}/#{late}/reorder", params: { orderedMenuIds: [late] },
                                    headers: auth_header(@token), as: :json
    assert_equal 200, response.status
    reorder_ids = JSON.parse(response.body).map { |m| m['id'] }
    assert_equal tied.sort, reorder_ids.select { |id| tied.include?(id) },
                 'reorder 响应并列组应按 id 升序'
  end

  private

  def create_menu(title, sort_order)
    post @base, params: { title: title, sortOrder: sort_order },
                headers: auth_header(@token), as: :json
    assert_equal 200, response.status
    JSON.parse(response.body)['id']
  end
end
