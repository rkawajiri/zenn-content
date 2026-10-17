#!/bin/bash
# データを空にして、5 章の最小モデルを登録し直す(画面の「Clear all data」+ setup-model.sh と同じ)。
# パラメータ・期間の軸・ユーザーは残る。9・10・11・14 章で「5 章のモデルだけの状態」に戻すときに使う。
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
cd "$(dirname "$0")" || exit 1
URL=${FREPPLE_URL:-http://localhost:9000}
USER=${FREPPLE_USER:-admin:admin}

# 実行画面の「Clear all data」が既定でチェックを入れている、データ用のモデル(DATA TABLES)。
# frePPLe の版で増減するので、実行画面の HTML から取り出す
query=$(curl -s -u "$USER" "$URL/execute/" | python3 -c '
import sys, re
print("&".join("models=" + m for m in re.findall(r"name=\"models\" data-tables=\"data\" value=\"([^\"]+)\"", sys.stdin.read())))')
[ -n "$query" ] || { echo "失敗: $URL/execute/ からモデルの一覧を取れません。URL と FREPPLE_USER を確認してください"; exit 1; }

resp=$(curl -s -u "$USER" -X POST "$URL/execute/api/empty/?$query")
tid=$(echo "$resp" | python3 -c "import sys,json;print(json.load(sys.stdin)['taskid'])" 2>/dev/null) || { echo "失敗: $resp"; exit 1; }

for i in $(seq 1 120); do
  st=$(curl -s -u "$USER" "$URL/execute/api/status/?id=$tid" |
    python3 -c "import sys,json;d=json.load(sys.stdin);print(d[sys.argv[1]]['status'])" "$tid" 2>/dev/null)
  case "$st" in
    Done|Failed|Canceled) break ;;
  esac
  sleep 1
done
echo "データを空にする task $tid: $st (${i}s)"
[ "$st" = "Done" ] || exit 1

./setup-model.sh
