# frozen_string_literal: true

require_relative '../test_helper'

# DB-First parity（ADR-0025 的 Rails 等价强制）：
# springboot 由 scaffold-entities.mjs 从 saas_dev 真库生成 entity（JPA 需显式字段声明）；
# AR 模型 schema-less（列运行时从 information_schema 读），无可生成实体内容 ——
# 漂移风险收敛为「table_name/主键错」，本测试连测试库 reflect 对账，拼错即红。
class SchemaParityTest < ActiveSupport::TestCase
  MODELS = [
    SysUser, Tenant, TenantMember, OauthClient, TenantApplication,
    OauthCode, OauthAccessToken, OauthRefreshToken,
    SysMenu, SysRole
  ].freeze

  # 复合主键 junction 表（无 id 列，drizzle 复合 pk）
  COMPOSITE = {
    'SysRoleMenu' => %w[role_id menu_id],
    'TenantMemberRole' => %w[member_id role_id]
  }.freeze

  test 'every model maps to a real table with a uuid pk' do
    (MODELS + COMPOSITE.keys.map(&:constantize)).each do |klass|
      table = klass.table_name
      assert ActiveRecord::Base.connection.table_exists?(table),
             "#{klass} -> #{table} does not exist in test DB"

      pk_cols = COMPOSITE[klass.name] || ['id']
      pk_cols.each do |col|
        assert klass.columns_hash.key?(col), "#{klass} missing pk column '#{col}'"
        next unless col == 'id'

        assert_equal :uuid, klass.columns_hash['id']&.type,
                     "#{klass} pk column 'id' should be uuid (drizzle default uuid_generate_v4)"
      end
    end
  end

  test 'models do not declare a rails schema (DB-First: no migrate/structure spill)' do
    assert_empty Dir[Rails.root.join('db/migrate/*.rb')],
                 'db/migrate is forbidden (schema SSOT = shared drizzle)'
    assert_not ActiveRecord::Base.connection.table_exists?('ar_internal_metadata'),
               'maintain_test_schema=false should keep rails metadata table away'
  end
end
