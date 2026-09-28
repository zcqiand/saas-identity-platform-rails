# frozen_string_literal: true

# 全局自然人用户（DB-First：schema SSOT = shared drizzle public.sys_user，禁 migrate）。
class SysUser < ApplicationRecord
  self.table_name = 'sys_user'

  has_many :tenant_members, foreign_key: :user_id, primary_key: :id
  # M01.F04.I02 失败锁定常量（家族口径：连续 5 次锁 15 分钟）
  LOCKOUT_THRESHOLD = 5
  LOCKOUT_MINUTES = 15

  # 密码校验：家族 dev 种子约定 "plain:{password}" 前缀 + bcrypt 兜底
  # （三后端同语义，否则同一份种子登录行为分叉 —— springboot AuthController 对齐）。
  def password_matches?(raw)
    return true if password == "plain:#{raw}"

    ::BCrypt::Password.new(password) == raw
  rescue BCrypt::Errors::InvalidHash
    false
  end
end
