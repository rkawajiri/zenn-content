#!/bin/bash
# 8 章の最小モデル(setup-model.sh で登録したもの)に、倉庫(warehouse)と、工場から倉庫への輸送を足す。
# 先に setup-model.sh を実行しておくこと。12 章で使う。
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
URL=${FREPPLE_URL:-http://localhost:9000}
USER=${FREPPLE_USER:-admin:admin}

post() {  # post <モデル名> <JSON>
  code=$(curl -s -u "$USER" -H "Content-Type: application/json" -X POST \
    "$URL/api/input/$1/?format=json" -d "$2" -o /tmp/frepple_setup.out -w "%{http_code}")
  printf '%-20s %s\n' "$1" "$code"
  [ "$code" = "201" ] || { cat /tmp/frepple_setup.out; echo; exit 1; }
}

# 納期は「今日」からの日数で作る
due() { python3 -c "from datetime import date,timedelta;print((date.today()+timedelta(days=$1)).isoformat()+'T00:00:00')"; }

post location  '[{"name":"warehouse"}]'
post customer  '[{"name":"customer B"}]'
# 工場(origin)から倉庫(location)へ、テーブルを 2 日かけて運ぶ。10 個単位でまとめて運ぶ。
post itemdistribution '[
  {"item":"table","location":"warehouse","origin":"factory","leadtime":"2 00:00:00","sizemultiple":10,"effective_start":"1971-01-01T00:00:00"}]'
# 倉庫に届く受注
post demand "[
  {\"name\":\"order 4\",\"item\":\"table\",\"location\":\"warehouse\",\"customer\":\"customer B\",\"quantity\":50,\"due\":\"$(due 10)\",\"status\":\"open\"}]"
echo "登録が終わりました"
