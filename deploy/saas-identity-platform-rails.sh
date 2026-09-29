#!/bin/sh
# Usage: saas-identity-platform-rails.sh <DOCKER_USERNAME> <DOCKER_PASSWORD> [VERSION]
#
# 由 .github/workflows/ci.yml 的 deploy job 远程调用:
#   ssh deploy@vps -- cd /home/deploy/saas-identity-platform-rails
#                    && sh saas-identity-platform-rails.sh $DOCKER_USERNAME $DOCKER_PASSWORD $VERSION
#
# VERSION 默认是 latest。tag-based deploy 时显式传 tag 名（v0.1.x-YYYYMMDD）。
# CI 同时 push :latest + :<tag> 两份镜像,回滚只要手动指定旧 tag 再跑一次本脚本。
#
# 与姊妹仓 saas-identity-platform-springboot.sh 的差异:
#   - 运行时 Rails 8.1 + puma，健康探针 /health（springboot 是 /actuator/health）
#   - rails 只认 PG_* 五件套连接形态（database.yml 全 ENV.fetch；DATABASE_URL 单串
#     仅供 deploy 脚本键集契约，运行时不读——.env.production 同款注释）
#   - SECRET_KEY_BASE 首启随机生成 append（rails prod 启动必需；家族 JWT_SIGNING_KEY
#     同款 append-only 模式）
#
# 前置: deploy 用户需在 docker 组中(sudo usermod -aG docker deploy)。
#        rails.env 必须由 setup-vps.sh 或本脚本首启生成。

set -eu

USERNAME="${1:-}"
PASSWORD="${2:-}"
VERSION="${3:-latest}"
IMAGE="${USERNAME}/saas-identity-platform-rails:${VERSION}"
BASE="/home/deploy/saas-identity-platform-rails"
CONTAINER_NAME="saas-identity-platform-rails"

# nginx domain（deploy 脚本渲染 nginx vhost 时用）
NGINX_DOMAIN="${NGINX_DOMAIN:-saas-rails.xiangru.uk}"
NGINX_CERT_BASENAME="${NGINX_CERT_BASENAME:-xiangru-uk}"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: $0 <DOCKER_USERNAME> <DOCKER_PASSWORD> [VERSION]" >&2
  exit 2
fi

# rails.env 自举保护: 缺失时, 如 $PG_* 五件套在环境里, 自动生成（含 CORS + JWT 契约值）;
# 否则 fail fast。setup-vps.sh 仍是首推（VPS 一次性）, 本分支仅给"先有 env 临时上线"场景。
# PG_PASSWORD 等真值家族 deploy 脚本一贯硬编码（springboot 版同款）——VPS env-file 600 权限。
if [ ! -f "$BASE/rails.env" ]; then
  if [ -n "${PG_HOST:-}" ] && [ -n "${PG_PASSWORD:-}" ]; then
    echo "→ bootstrapping $BASE/rails.env from env PG_HOST/PG_PASSWORD (key 集合 = .env.production)"
    umask 077
    {
      printf 'SERVER_PORT=5106\n'
      printf 'PG_HOST=%s\n' "${PG_HOST:-100.79.128.25}"
      printf 'PG_PORT=5432\n'
      printf 'PG_USER=%s\n' "${PG_USER:-postgres}"
      printf 'PG_PASSWORD=%s\n' "$PG_PASSWORD"
      printf 'PG_DATABASE=saas_prod\n'
      # JWT 契约值与 .env.production 相同（消费方 whoami 内省不本地验签）
      printf 'JWT_SIGNING_KEY=%s\n' "${JWT_SIGNING_KEY:-$(head -c 48 /dev/urandom | base64 | tr -d '\n')}"
      printf 'JWT_ISSUER=saas-identity-platform\n'
      printf 'JWT_AUDIENCE=saas-identity-platform-clients\n'
      printf 'JWT_TTL_SECONDS=3600\n'
      # 默认 CORS 白名单：vue/react SPA + saas-nextjs + 本仓域名。运维可手工追加 origin。
      printf 'SAAS_CORS_ALLOWED_ORIGINS=https://%s,https://saas-vue.xiangru.uk,https://saas-react.xiangru.uk,https://saas-nextjs.xiangru.uk\n' "$NGINX_DOMAIN"
      # rails prod 启动必需，首启随机生成
      printf 'SECRET_KEY_BASE=%s\n' "$(head -c 48 /dev/urandom | base64 | tr -d '\n')"
      # —— 兼容键（键集相等契约；rails 运行时只读 PG_* 五件套 + JWT + CORS + SECRET_KEY_BASE，
      # DATABASE_URL 单串不编码不消费，仅为 L0.5 键集相等而存在） ——
      printf 'DATABASE_URL=postgresql://%s:%s@%s:5432/saas_prod\n' "${PG_USER:-postgres}" "$PG_PASSWORD" "${PG_HOST:-100.79.128.25}"
      printf 'DATABASE_NAME=saas_prod\n'
      printf 'DATABASE_USER=%s\n' "${PG_USER:-postgres}"
      printf 'DATABASE_PASSWORD=%s\n' "$PG_PASSWORD"
      printf 'JWT_AUTHORITY=https://auth.example.com\n'
    } > "$BASE/rails.env"
    chown deploy:deploy "$BASE/rails.env" 2>/dev/null || true
    chmod 600 "$BASE/rails.env"
  else
    echo "ERROR: $BASE/rails.env missing. Set PG_HOST/PG_PASSWORD env (e.g. sudo -E sh deploy/setup-vps.sh saas-rails.example.com) or run setup-vps.sh first." >&2
    exit 1
  fi
fi
if ! grep -q '^PG_HOST=' "$BASE/rails.env"; then
  echo "ERROR: $BASE/rails.env has no PG_HOST line" >&2
  exit 1
fi

# nginx vhost 重渲染（每次 deploy 都跑,ADR-0018:容器端口变了 vhost 必须跟）:
# 模板从 master 拉,渲染后写入 sites-available,symlink sites-enabled,再 sudo nginx -t + reload。
# diff 检测:内容未变跳过 reload (nginx -t 也省)。
# 每次都从 master 拉最新 —— VPS 本地老模板会渲染出老端口全家族 502（2026-09-03 事故）。
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
NGINX_VHOST_FILE="${NGINX_SITES_AVAILABLE}/${NGINX_DOMAIN}"
NGINX_VHOST_LINK="${NGINX_SITES_ENABLED}/${NGINX_DOMAIN}"
NGINX_TEMPLATE="${BASE}/nginx-vps.conf.example"

echo "→ fetching nginx-vps.conf.example template (always fresh from master)"
curl -fsSL "https://raw.githubusercontent.com/zcqiand/saas-identity-platform-rails/refs/heads/master/deploy/nginx-vps.conf.example" -o "${NGINX_TEMPLATE}"

# 渲染到临时文件 —— sed 顺序：cert 归一化规则必须排在 <domain>/YOUR_DOMAIN 通配之前
# （先替换 <domain> 会把 cert 路径占位符一并吃掉,2026-09-03 事故根因）。
TMP_VHOST="$(mktemp -t vpstpl.XXXXXX)"
sed \
  -e "s|/etc/nginx/ssl/<domain>\.crt|/etc/nginx/ssl/${NGINX_CERT_BASENAME}.cert|g" \
  -e "s|/etc/nginx/ssl/<domain>\.cert|/etc/nginx/ssl/${NGINX_CERT_BASENAME}.cert|g" \
  -e "s|/etc/nginx/ssl/<domain>\.key|/etc/nginx/ssl/${NGINX_CERT_BASENAME}.key|g" \
  -e "s|/etc/nginx/ssl/your-cert\.crt|/etc/nginx/ssl/${NGINX_CERT_BASENAME}.cert|g" \
  -e "s|/etc/nginx/ssl/your-cert\.cert|/etc/nginx/ssl/${NGINX_CERT_BASENAME}.cert|g" \
  -e "s|/etc/nginx/ssl/your-cert\.key|/etc/nginx/ssl/${NGINX_CERT_BASENAME}.key|g" \
  -e "s|<domain>|${NGINX_DOMAIN}|g" \
  -e "s|lab\.YOUR_DOMAIN|${NGINX_DOMAIN}|g" \
  -e "s|saas\.YOUR_DOMAIN|${NGINX_DOMAIN}|g" \
  "${NGINX_TEMPLATE}" > "${TMP_VHOST}"

if [ -e "${NGINX_VHOST_FILE}" ] && diff -q "${TMP_VHOST}" "${NGINX_VHOST_FILE}" >/dev/null 2>&1; then
  echo "→ nginx vhost ${NGINX_VHOST_FILE} unchanged, skip"
  rm -f "${TMP_VHOST}"
else
  echo "→ rendering nginx vhost ${NGINX_VHOST_FILE} (domain=${NGINX_DOMAIN} cert=${NGINX_CERT_BASENAME})"
  if [ -w "${NGINX_SITES_AVAILABLE}" ]; then
    cp "${TMP_VHOST}" "${NGINX_VHOST_FILE}"
  else
    sudo cp "${TMP_VHOST}" "${NGINX_VHOST_FILE}" \
      || { echo "ERROR: sudo cp ${NGINX_VHOST_FILE} failed"; rm -f "${TMP_VHOST}"; exit 1; }
  fi
  if [ -w "${NGINX_SITES_ENABLED}" ]; then
    ln -sf "${NGINX_VHOST_FILE}" "${NGINX_VHOST_LINK}"
  else
    sudo ln -sf "${NGINX_VHOST_FILE}" "${NGINX_VHOST_LINK}" \
      || { echo "ERROR: sudo ln ${NGINX_VHOST_LINK} failed"; rm -f "${TMP_VHOST}"; exit 1; }
  fi
  rm -f "${TMP_VHOST}"
  echo "→ nginx -t"
  sudo nginx -t
  echo "→ systemctl reload nginx"
  sudo systemctl reload nginx
  echo "✓ nginx reloaded"
fi

# 存量 env-file 补键：逐 key append-if-missing 到 .env.production 全集
# (key 集合契约由 suite L0.5 check_deploy_parity 锁死;显式写值,漂移在 deploy 期暴露)。
if [ -f "$BASE/rails.env" ]; then
  append_if_missing() {
    key="$1"; val="$2"
    if ! grep -q "^${key}=" "$BASE/rails.env"; then
      echo "→ append ${key} to existing $BASE/rails.env"
      umask 077
      printf '%s=%s\n' "$key" "$val" >> "$BASE/rails.env"
    fi
  }
  append_if_missing SERVER_PORT '5106'
  append_if_missing PG_HOST '100.79.128.25'
  append_if_missing PG_PORT '5432'
  append_if_missing PG_USER 'postgres'
  append_if_missing PG_PASSWORD "${PG_PASSWORD:-}"
  append_if_missing PG_DATABASE 'saas_prod'
  append_if_missing JWT_ISSUER 'saas-identity-platform'
  append_if_missing JWT_AUDIENCE 'saas-identity-platform-clients'
  append_if_missing JWT_TTL_SECONDS '3600'
  append_if_missing DATABASE_NAME 'saas_prod'
  append_if_missing JWT_AUTHORITY 'https://auth.example.com'

  # SECRET_KEY_BASE 缺失/空值补随机（rails prod 启动必需；已有值不覆盖——
  # 重启后 session/verifier 密钥保持稳定,存量 cookie 不失效）
  if ! grep -q '^SECRET_KEY_BASE=..*' "$BASE/rails.env"; then
    echo "→ append SECRET_KEY_BASE (random, persisted) to existing $BASE/rails.env"
    umask 077
    printf 'SECRET_KEY_BASE=%s\n' "$(head -c 48 /dev/urandom | base64 | tr -d '\n')" >> "$BASE/rails.env"
  fi
  # JWT_SIGNING_KEY 同款缺失/空值补随机
  if ! grep -q '^JWT_SIGNING_KEY=..*' "$BASE/rails.env"; then
    echo "→ append JWT_SIGNING_KEY (random, persisted) to existing $BASE/rails.env"
    umask 077
    printf 'JWT_SIGNING_KEY=%s\n' "$(head -c 48 /dev/urandom | base64 | tr -d '\n')" >> "$BASE/rails.env"
  fi

  # origin 级无损追加（家族同款）：三前端 + 本域都可跨源调本后端，
  # 存量 env-file 缺哪个 origin 就补哪个（不整值覆盖，运维手工 origin 保留）。
  for cors_origin in "https://${NGINX_DOMAIN}" \
                     "https://saas-nextjs.xiangru.uk" \
                     "https://saas-react.xiangru.uk" \
                     "https://saas-vue.xiangru.uk"; do
    if grep -q '^SAAS_CORS_ALLOWED_ORIGINS=' "$BASE/rails.env" && ! grep '^SAAS_CORS_ALLOWED_ORIGINS=' "$BASE/rails.env" | grep -qF "$cors_origin"; then
      sed -i "s#^\(SAAS_CORS_ALLOWED_ORIGINS=.*\)#\1,${cors_origin}#" "$BASE/rails.env"
      echo "→ reconcile SAAS_CORS_ALLOWED_ORIGINS: 追加缺失 origin ${cors_origin}（origin 级，不整值覆盖）"
    fi
  done
fi

echo "→ image: $IMAGE"
echo "→ docker login"
printf '%s' "$PASSWORD" | docker login -u "$USERNAME" --password-stdin

echo "→ docker pull"
docker pull "$IMAGE"

echo "→ docker stop & rm $CONTAINER_NAME"
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

echo "→ docker run"
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "127.0.0.1:5106:5106" \
  --env-file "$BASE/rails.env" \
  "$IMAGE"

echo "→ docker image prune"
docker image prune -f

echo "→ docker ps"
docker ps --filter name="$CONTAINER_NAME"

# 健康检查: 直接 wget /health 探 200（springboot 用 /actuator/health,rails 是仓内
# 裸 /health 路由）。容器死亡提前终止循环, 立刻报失败。
i=0
while [ $i -lt 120 ]; do
  if wget --tries=1 --timeout=3 -q "http://127.0.0.1:5106/health" -O /dev/null 2>/dev/null; then
    echo "→ /health 200 (host 127.0.0.1:5106) after ${i}s"
    break
  fi
  if ! docker inspect --format='{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; then
    echo "→ container not running, logs:"
    docker logs --tail 30 "$CONTAINER_NAME"
    exit 1
  fi
  i=$((i+1))
  sleep 1
done

if [ $i -ge 120 ]; then
  echo "→ /health 仍未 200（120s 上限）, logs:"
  docker logs --tail 30 "$CONTAINER_NAME"
  exit 1
fi

echo "→ deploy done at $(date -u)"
