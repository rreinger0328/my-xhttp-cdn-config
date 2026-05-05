# ==================================================
# 读取已有节点参数
# ==================================================

echo -e "\n${CYAN}[+] 添加扩展模式：上行 xhttp+Reality IPv4 / IPv6 | 下行 xhttp+Reality IPv6 / IPv4${NC}\n"
echo -e "${YELLOW}[+] 前置条件${NC}"
echo "  1. 已经成功运行主脚本"
echo "  2. 这里只同步 xpadding，不需要 ECH"
echo "  3. VPS 的 IPv4 与 IPv6 都可以访问 443"
echo "  4. 两个 Reality 域名 DNS 分别指向 IPv4 / IPv6，且保持仅 DNS（灰色云朵）"
echo ""

find_client_files
info "读取已有客户端配置: $USER_HOME"

BASE_LINE=$(grep -F '#xhttp%2BReality%20%E4%B8%8A%E4%B8%8B%E8%A1%8C%E4%B8%8D%E5%88%86%E7%A6%BB' "$V2RAYN_FILE" | head -n1 | tr -d '\r' || true)
[[ -n "$BASE_LINE" ]] || error "未找到 xhttp+Reality 上下行不分离节点，无法自动读取参数"

UUID2=$(extract_uri_user "$BASE_LINE")
BASE_SERVER=$(strip_ipv6_brackets "$(extract_uri_server "$BASE_LINE")")
XHTTP_PATH=$(get_query_param "$BASE_LINE" "path" || true)
VLESSENC_ENCRYPTION=$(get_query_param "$BASE_LINE" "encryption" || true)
REALITY_DOMAIN=$(get_query_param "$BASE_LINE" "sni" || true)
PUBLIC_KEY=$(get_query_param "$BASE_LINE" "pbk" || true)
SHORT_ID=$(get_query_param "$BASE_LINE" "sid" || true)
BASE_EXTRA_ENC=$(get_query_param "$BASE_LINE" "extra" || true)

[[ -n "$UUID2" ]] || error "读取 UUID2 失败"
[[ -n "$XHTTP_PATH" ]] || error "读取 XHTTP Path 失败"
[[ -n "$VLESSENC_ENCRYPTION" ]] || error "读取 VLESS Encryption 失败"
[[ -n "$REALITY_DOMAIN" ]] || error "读取 Reality 域名失败"
[[ -n "$PUBLIC_KEY" ]] || error "读取 Reality Public Key 失败"
[[ -n "$SHORT_ID" ]] || error "读取 Reality Short ID 失败"

OLD_REALITY_DOMAINS=()
add_old_reality_domain() {
  local domain="$1" existing
  [[ -n "$domain" ]] || return 0
  [[ "$domain" == "$REALITY_DOMAIN" ]] && return 0
  for existing in "${OLD_REALITY_DOMAINS[@]}"; do
    [[ "$existing" == "$domain" ]] && return 0
  done
  OLD_REALITY_DOMAINS+=("$domain")
}

while IFS= read -r old_line; do
  add_old_reality_domain "$(get_query_param "$old_line" "sni" || true)"
done < <(grep -F 'xhttp%2BReality%20IPv' "$V2RAYN_FILE" | tr -d '\r' || true)

DEFAULT_IPV4=""
DEFAULT_IPV6=""
if [[ "$BASE_SERVER" == *:* ]]; then
  DEFAULT_IPV6="$BASE_SERVER"
else
  DEFAULT_IPV4="$BASE_SERVER"
fi

if command -v curl >/dev/null 2>&1; then
  IPV4_ADDRESS=$(curl -4 -s --max-time 5 ip.sb || true)
  IPV6_ADDRESS=$(curl -6 -s --max-time 5 ip.sb || true)
fi

IPV4_ADDRESS=${IPV4_ADDRESS:-$DEFAULT_IPV4}
IPV6_ADDRESS=${IPV6_ADDRESS:-$DEFAULT_IPV6}
IPV6_ADDRESS=$(strip_ipv6_brackets "$IPV6_ADDRESS")

[[ -n "$IPV4_ADDRESS" ]] || error "IPv4 地址不能为空"
[[ "$IPV4_ADDRESS" != *:* ]] || error "IPv4 地址格式错误"
[[ -n "$IPV6_ADDRESS" ]] || error "IPv6 地址不能为空"
[[ "$IPV6_ADDRESS" == *:* ]] || error "IPv6 地址格式错误"

IPV4_URI=$(format_uri_host "$IPV4_ADDRESS")
IPV6_URI=$(format_uri_host "$IPV6_ADDRESS")

read -rp "请输入 IPv4 Reality 域名: " REALITY_DOMAIN_V4
[[ -n "$REALITY_DOMAIN_V4" ]] || error "IPv4 Reality 域名不能为空"

read -rp "请输入 IPv6 Reality 域名: " REALITY_DOMAIN_V6
[[ -n "$REALITY_DOMAIN_V6" ]] || error "IPv6 Reality 域名不能为空"
[[ "$REALITY_DOMAIN_V4" != "$REALITY_DOMAIN_V6" ]] || error "IPv4 / IPv6 Reality 域名不能相同"

echo ""
echo -e "${YELLOW}[+] IPv4 / IPv6 回落网站${NC}"
read -rp "请输入 IPv4 Reality 回落网站 [默认 https://www.stanford.edu]: " FALLBACK_URL_V4
FALLBACK_URL_V4=${FALLBACK_URL_V4:-https://www.stanford.edu}
read -rp "请输入 IPv6 Reality 回落网站 [默认 https://www.harvard.edu]: " FALLBACK_URL_V6
FALLBACK_URL_V6=${FALLBACK_URL_V6:-https://www.harvard.edu}

FALLBACK_ORIGIN_V4=$(normalize_proxy_origin "$FALLBACK_URL_V4") || error "IPv4 Reality 回落网站格式无效"
FALLBACK_ORIGIN_V6=$(normalize_proxy_origin "$FALLBACK_URL_V6") || error "IPv6 Reality 回落网站格式无效"
FALLBACK_HOST_V4=$(extract_host_from_url "$FALLBACK_ORIGIN_V4")
FALLBACK_HOST_V6=$(extract_host_from_url "$FALLBACK_ORIGIN_V6")

if [[ "$FALLBACK_ORIGIN_V4" == "$FALLBACK_ORIGIN_V6" ]]; then
  warn "IPv4 / IPv6 回落网站相同，建议分别设置不同伪装站"
fi

info "IPv4 地址:    $IPV4_ADDRESS"
info "IPv6 地址:    $IPV6_ADDRESS"
info "IPv4 Reality: $REALITY_DOMAIN_V4"
info "IPv6 Reality: $REALITY_DOMAIN_V6"
info "IPv4 回落:    $FALLBACK_ORIGIN_V4"
info "IPv6 回落:    $FALLBACK_ORIGIN_V6"
info "XHTTP Path:   $XHTTP_PATH"
echo ""
