#!/bin/bash
# 5 章の最小モデル(setup-model.sh で登録したもの)に、倉庫(warehouse)と、工場から倉庫への輸送を足す。
# 先に setup-model.sh を実行しておくこと。10 章で使う。
#
# 使い方: ./setup-distribution.sh [シナリオ名](シナリオ名を省くと default に登録する)
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
. "$(dirname "$0")/common.sh"
use_scenario "$1"

post location  '[{"name":"warehouse"}]'
post customer  '[{"name":"customer B"}]'
# 工場(origin)から倉庫(location)へ、テーブルを 2 日かけて運ぶ。10 個単位でまとめて運ぶ。
post itemdistribution '[
  {"item":"table","location":"warehouse","origin":"factory","leadtime":"2 00:00:00","sizemultiple":10,"effective_start":"1971-01-01T00:00:00"}]'
# 倉庫に届く受注
post demand "[
  {\"name\":\"order 4\",\"item\":\"table\",\"location\":\"warehouse\",\"customer\":\"customer B\",\"quantity\":50,\"due\":\"$(due 10)\",\"status\":\"open\"}]"
echo "登録が終わりました"
