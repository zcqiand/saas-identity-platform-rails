# =============================================================================
# saas-identity-platform-rails — 生产镜像
#
#   builder  → ruby:3.4-slim + build-essential/libpq-dev：bundle install（pg/puma
#              原生扩展在 builder 编译），产物 gems + app 码
#   runtime  → ruby:3.4-slim + libpq5（运行期动态库），puma 监听 SERVER_PORT=5106
#
# 数据库：PostgreSQL（远程）。容器内不持有 DB 文件 —— 运行期 PG_* 五件套由 VPS
#         env-file 注入（database.yml 全 ENV.fetch fail-fast，无默认兜底）。
#         家族 DB-First：schema SSOT=shared drizzle，本镜像禁 db:migrate（只连不建）。
#
# 端口：host=container=5106（ADR-0018 单层 port，docker run -p 127.0.0.1:5106:5106；
#       saas 家族 X06 段）；VPS nginx 反代 127.0.0.1:5106 → https://saas-rails.xiangru.uk
#
# 镜像族系：springboot builder=maven+temurin / nextjs=node:24-slim / 本仓=ruby:3.4-slim。
# runtime 与 builder 同 base（3.4-slim），原生扩展（pg/puma）编译产物直接可用，
# 不需要再装 build-essential —— 只补 libpq5（libpq 运行期 so）。
# =============================================================================

# ---------- Stage 1: builder ----------
FROM ruby:3.4-slim AS builder
WORKDIR /app

# git：部分 gem 从 git 源拉取；build-essential+libpq-dev：pg/puma 原生扩展编译
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential libpq-dev git \
 && rm -rf /var/lib/apt/lists/*

# 缓存友好的层：先只复制 Gemfile*.lock 跑 bundle install，
# 再 copy 应用码。多数 commit 只动码，gems 缓存命中。
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true \
 && bundle config set --local without 'development test' \
 && bundle install --jobs 4

COPY . .

# ---------- Stage 2: runtime ----------
FROM ruby:3.4-slim AS runtime
WORKDIR /app

# libpq5：pg gem 运行期动态库（builder 装的是 libpq-dev 编译头）；wget：HEALTHCHECK
RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq5 wget ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# gems 从 builder 拷（bundle config deployment 把 gems 放 vendor/bundle，随 app 走）
COPY --from=builder /app /app

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    SERVER_PORT=5106 \
    TZ=UTC

EXPOSE 5106

# Rails 冷启动 3-8s @ 小 VPS；probe 探仓内 /health（contract-test healthcheck 同款）。
# 未就绪返回 5xx → HEALTHCHECK exit 1 → restart-loop，fail-loud 是想要的。
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:5106/health || exit 1

# RAILS_MASTER_KEY 不用（家族不用加密凭据，prod 走 ENV SECRET_KEY_BASE）；
# puma 读 config/puma.rb 的 ENV.fetch("SERVER_PORT")。
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
