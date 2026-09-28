# frozen_string_literal: true

source 'https://rubygems.org'

# 版本锁（profiles/codegen.md §4）：rails 7.2.x exact / pg 1.5 / puma 6 / jwt 2.8 / rubocop 1.60+
# 升级单独立项 ADR。禁止 bundle update 无钉版漂移。
gem 'jwt', '~> 2.8'
gem 'pg', '~> 1.5'
gem 'puma', '~> 6.6'
gem 'rack-cors', '~> 2.0'
gem 'rails', '8.1.4'

# .env 三件套加载（L0.5 键集契约文件；test 链自动载 .env.test）
gem 'dotenv-rails', '~> 3.1'

# Windows 时区数据（家族构建机 Windows 11 实证必需）
gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  # 仓级 L2.security 静态安全扫描（.harness/stack.json）
  gem 'brakeman', require: false
end

group :lint do
  # 家族 L1/L2 门：rubocop --only Layout / rubocop（profiles/rails.toml）
  gem 'rubocop', '~> 1.60', require: false
end
