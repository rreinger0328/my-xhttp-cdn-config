# ==================================================
# 证书与 Nginx
# ==================================================

command -v acme.sh >/dev/null 2>&1 || error "未找到 acme.sh，请先运行主脚本"
command -v nginx >/dev/null 2>&1 || error "未找到 nginx，请先运行主脚本"

CDN_CERT_DOMAINS=()
add_unique_cdn_domain() {
  local domain="$1" existing
  [[ -n "$domain" ]] || return 0
  for existing in "${CDN_CERT_DOMAINS[@]}"; do
    [[ "$existing" == "$domain" ]] && return 0
  done
  CDN_CERT_DOMAINS+=("$domain")
}

add_unique_cdn_domain "$DEFAULT_CDN_DOMAIN"
add_unique_cdn_domain "$CDN_B"
add_unique_cdn_domain "$CDN_A"

ACME_DOMAIN_ARGS=(-d "$REALITY_DOMAIN")
for domain in "${CDN_CERT_DOMAINS[@]}"; do
  ACME_DOMAIN_ARGS+=(-d "$domain")
done

ACME_CERT_HOME="/root/.acme.sh/${REALITY_DOMAIN}_ecc"
ACME_CERT_CONF="${ACME_CERT_HOME}/${REALITY_DOMAIN}.conf"
ACME_LISTEN_ARGS=()
[[ "$VPS_SERVER" == \[*\] ]] && ACME_LISTEN_ARGS=(--listen-v6)

have_existing_cdn_cert() {
  [[ -f "$ACME_CERT_CONF" ]] || return 1
  [[ -f "$ACME_CERT_HOME/fullchain.cer" ]] || return 1
  [[ -f "$ACME_CERT_HOME/${REALITY_DOMAIN}.key" ]] || return 1

  local cert_domains domain
  cert_domains=$(grep -E "^(Le_Domain|Le_Alt)=" "$ACME_CERT_CONF" 2>/dev/null | cut -d"'" -f2 | tr ',' '\n' || true)
  for domain in "${CDN_CERT_DOMAINS[@]}"; do
    grep -Fxq "$domain" <<< "$cert_domains" || return 1
  done
}

if have_existing_cdn_cert; then
  info "检测到证书已包含 CDN-A / CDN-B，跳过重新签发"
else
  info "申请 / 更新包含 CDN-A、CDN-B 的证书..."
  set +e
  ISSUE_OUTPUT=$(acme.sh --issue "${ACME_DOMAIN_ARGS[@]}" \
    --standalone "${ACME_LISTEN_ARGS[@]}" --keylength ec-256 \
    --pre-hook "${NGINX_STOP_CMD} 2>/dev/null || true" \
    --post-hook "${NGINX_START_CMD} 2>/dev/null || true" 2>&1)
  ISSUE_CODE=$?
  set -e
  echo "$ISSUE_OUTPUT"
  if [[ $ISSUE_CODE -ne 0 ]] && ! echo "$ISSUE_OUTPUT" | grep -Eqi 'Domains not changed|Skipping\. Next renewal time'; then
    error "包含 CDN-A / CDN-B 的证书申请失败"
  fi
fi

info "安装证书..."
acme.sh --install-cert -d "$REALITY_DOMAIN" --ecc \
  --key-file /etc/ssl/private/private.key \
  --fullchain-file /etc/ssl/private/fullchain.cer \
  --reloadcmd "${NGINX_RESTART_CMD}"

NGINX_CONF="/etc/nginx/nginx.conf"
[[ -f "$NGINX_CONF" ]] || error "未找到 $NGINX_CONF"

if grep server_name "$NGINX_CONF" | grep -F "$CDN_A" | grep -qF "$CDN_B"; then
  info "Nginx 已包含 CDN-A / CDN-B server_name，跳过修改"
else
  NGINX_BAK="${NGINX_CONF}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$NGINX_CONF" "$NGINX_BAK"
  tmp_nginx=$(mktemp)
  awk -v base_cdn="$DEFAULT_CDN_DOMAIN" -v cdn_a="$CDN_A" -v cdn_b="$CDN_B" '
    /^[[:space:]]*server_name[[:space:]]/ && index($0, base_cdn) {
      if (!index($0, cdn_a)) {
        sub(/[[:space:]]*;[[:space:]]*$/, " " cdn_a ";")
      }
      if (!index($0, cdn_b)) {
        sub(/[[:space:]]*;[[:space:]]*$/, " " cdn_b ";")
      }
    }
    { print }
  ' "$NGINX_CONF" > "$tmp_nginx"
  cat "$tmp_nginx" > "$NGINX_CONF"
  rm -f "$tmp_nginx"
  info "已追加 CDN-A / CDN-B 到 Nginx，备份: $NGINX_BAK"
fi

nginx -t
service_restart nginx
