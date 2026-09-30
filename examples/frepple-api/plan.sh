#!/bin/bash
# frePPLe の計画を、Web API(/execute/api/runplan/)で実行し、終わるまで待つ。
#
# 使い方:
#   ./plan.sh "plantype=2&constraint=0&env=supply"                       # 制約なし
#   ./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply"       # 制約あり
#   ./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply" scenario1   # シナリオの中で実行
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
URL=${FREPPLE_URL:-http://localhost:9000}
USER=${FREPPLE_USER:-admin:admin}
P=${2:+/$2}

resp=$(curl -s -u "$USER" -X POST "$URL$P/execute/api/runplan/?$1")
tid=$(echo "$resp" | python3 -c "import sys,json;print(json.load(sys.stdin)['taskid'])") || { echo "起動に失敗: $resp"; exit 1; }

for i in $(seq 1 300); do
  st=$(curl -s -u "$USER" "$URL$P/execute/api/status/?id=$tid" |
    python3 -c "import sys,json;d=json.load(sys.stdin);print(d[sys.argv[1]]['status'])" "$tid" 2>/dev/null)
  case "$st" in
    Done|Failed|Canceled) break ;;
  esac
  sleep 1
done
echo "task $tid: $st (${i}s)"
[ "$st" = "Done" ]
