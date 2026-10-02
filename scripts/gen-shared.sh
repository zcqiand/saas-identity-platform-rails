#!/bin/bash
# Sync contract face from the shared repo's OpenAPI product.
#
# Architecture (ADR-0007 + ADR-0025 + ADR-0029):
# - shared repo is the schema-first dual-SSOT repo (TypeSpec -> OpenAPI.yaml)
# - rails consumes the generated openapi.yaml via the self-built gen-manifest.rb
#   (openapi-generator has no mature Rails server generator, see codegen.md §1)
# - output lib/generated/api_manifest.json is committed; L4.codegen.idempotent
#   re-runs this script and diffs bytes

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "$0")/../../saas-identity-platform-shared" && pwd)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENAPI="$SHARED_DIR/generated/openapi/openapi.yaml"

echo "[gen-shared] step 1/2 — shared: emit OpenAPI.yaml..."
(cd "$SHARED_DIR" && npm run emit:openapi)

if [ ! -f "$OPENAPI" ]; then
  echo "[gen-shared] ERROR: missing $OPENAPI" >&2
  exit 1
fi

echo "[gen-shared] step 2/2 — rails: gen-manifest.rb -> lib/generated/api_manifest.json"
(cd "$ROOT" && bundle exec ruby scripts/gen-manifest.rb "$OPENAPI")

echo "[gen-shared] OK"

# ADR-0026 §2: write last-gen-shared.json marker for the suite's cross-repo
# staleness check. Rails consumes only the API channel (no db channel: schema
# is consumed via PG directly, entity scaffolding is Stage-C+ if ever needed).
# Failure does not block: staleness is warning (V1 tier), not a build blocker.
SHARED_SHA=$(cd "$SHARED_DIR" && git rev-parse HEAD)
MARKER="$ROOT/.state/last-gen-shared.json"
mkdir -p "$ROOT/.state"
if python - "$MARKER" "$SHARED_SHA" "$(basename "$0")" "$(basename "$ROOT")" <<'PYEOF'
import datetime, json, sys

marker_path, shared_sha, cmd, repo = sys.argv[1:5]
try:
    with open(marker_path, encoding="utf-8") as f:
        marker = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    marker = {}

# rails: api_synced channel only; same-sha zero write (5.77) keeps mtime.
if cmd.startswith("gen-shared"):
    channel = "api_synced"
else:
    channel = None

if channel is not None and marker.get(channel + "_sha") == shared_sha:
    print("[marker] %s_sha unchanged (%s...) - zero write, keep timestamp (5.77)"
          % (channel, shared_sha[:12]))
    sys.exit(3)

now = datetime.datetime.now(datetime.timezone.utc).isoformat()
if channel is not None:
    marker[channel + "_sha"] = shared_sha
    marker[channel + "_at"] = now
    marker[channel + "_cmd"] = cmd

entries = [
    (marker.get(k + "_at", ""), marker[k + "_sha"])
    for k in ("api_synced",)
    if marker.get(k + "_sha")
]
marker["shared_sha"] = max(entries)[1] if entries else shared_sha
marker["consumer_repo"] = repo

with open(marker_path, "w", encoding="utf-8") as f:
    json.dump(marker, f, ensure_ascii=False, indent=2)
    f.write("\n")
PYEOF
then
  echo "[gen-shared]    ADR-0026 marker written: $MARKER (shared HEAD ${SHARED_SHA:0:7})"
else
  rc=$?
  if [ "$rc" -eq 3 ]; then
    echo "[gen-shared]    ADR-0026 marker sha unchanged, zero write (5.77): $MARKER"
  else
    echo "[gen-shared]    WARN: marker write failed - staleness will report UNKNOWN" >&2
  fi
fi

# REQ-2026-001: Swagger UI 数据副本 —— shared openapi.yaml -> public/api-docs/openapi.json。
# SSOT 是 shared 仓 openapi.yaml：UI 副本仅做 yaml->json + servers 同源改写。
# shared 的 servers 是 api.example.com 占位符；契约 paths 已带 /api 前缀，
# 同源空串让 swagger try-it-out 打本域。勿手改 openapi.json，改契约后重跑本脚本。
echo "[gen-shared] step 3 — rails: openapi.yaml -> public/api-docs/openapi.json (servers -> same-origin)"
(cd "$ROOT" && ruby -ryaml -rjson -e '
  src, dst = ARGV
  doc = YAML.load_file(src, aliases: true)
  doc["servers"] = [{ "url" => "", "description" => "当前后端（同源）" }]
  File.write(dst, JSON.pretty_generate(doc) + "\n")
' "$OPENAPI" "$ROOT/public/api-docs/openapi.json")
echo "[gen-shared]    wrote $ROOT/public/api-docs/openapi.json"
