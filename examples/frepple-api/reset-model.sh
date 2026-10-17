#!/bin/bash
# データを空にして、5 章の最小モデルを登録し直す(画面の「Clear all data」+ setup-model.sh と同じ)。
# パラメータ・期間の軸・ユーザーは残る。9・10・11・14 章で「5 章のモデルだけの状態」に戻すときに使う。
#
# 使い方:
#   ./reset-model.sh              # default のデータベース
#   ./reset-model.sh scenario2    # シナリオの中で作業しているときは、シナリオ名を付ける
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
cd "$(dirname "$0")" || exit 1
. ./common.sh
use_scenario "$1"

# 実行画面の「Clear all data」が既定でチェックを入れている、データ用のモデル(DATA TABLES)。
# frePPLe の版で増減するので、実行画面の HTML から取り出す
request "/execute/"
query=$(echo "$resp" | python3 -c '
import sys
from html.parser import HTMLParser
class P(HTMLParser):
    models = []
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if (tag == "input" and a.get("name") == "models" and a.get("data-tables") == "data"
                and "checked" in a and a.get("value") and "models=" + a["value"] not in self.models):
            self.models.append("models=" + a["value"])
p = P()
p.feed(sys.stdin.read())
print("&".join(p.models))')
[ -n "$query" ] || { echo "失敗: $URL$P/execute/ の画面から、データを空にするモデルの一覧を取り出せません。frePPLe の版を確認してください(9.17.0 で確認しています)"; exit 1; }

run_task "/execute/api/empty/?$query" 120
echo "データを空にする task $tid: $st (${i}s)"
[ "$st" = "Done" ] || exit 1

./setup-model.sh "$1"
