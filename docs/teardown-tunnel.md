# Tear down temporary tunnel (operator machine)

最后更新：2026-07-19 02:45

## Resources created by this project

| Resource | Value |
|----------|--------|
| Tunnel name | `molab-llm-tmp` |
| Tunnel UUID | (see local secrets `tunnel-molab-llm-tmp.token` / operator notes) |
| DNS | `llm.vectorcontrol.tech` CNAME → `<uuid>.cfargotunnel.com` (proxied) |

## Steps

1. Stop sandbox processes: `bash scripts/09_stop_local.sh`
2. Delete DNS record `llm` in zone `vectorcontrol.tech`
3. Delete Cloudflare tunnel `molab-llm-tmp`
4. Remove local secret files: `tunnel-molab-llm-tmp.token`, any credentials JSON
5. Wipe sandbox `/tmp/.secrets`

Do **not** leave a public hostname pointing at a dead tunnel.
