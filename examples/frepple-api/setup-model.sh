#!/bin/bash
# 5 章の最小モデル(テーブルを作る小さな工場)を、REST API でまとめて登録する。
# 先に 5 章の手順で「Clear all data」を実行して、データを空にしておくこと。
#
# 使い方: ./setup-model.sh [シナリオ名](シナリオ名を省くと default に登録する)
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
. "$(dirname "$0")/common.sh"
use_scenario "$1"

post location  '[{"name":"factory"}]'
post customer  '[{"name":"customer A"}]'
post item      '[{"name":"table"},{"name":"plank"},{"name":"screw"}]'
post supplier  '[{"name":"lumber shop"}]'
post itemsupplier '[
  {"supplier":"lumber shop","item":"plank","location":"factory","leadtime":"3 00:00:00","effective_start":"1971-01-01T00:00:00"},
  {"supplier":"lumber shop","item":"screw","location":"factory","leadtime":"1 00:00:00","effective_start":"1971-01-01T00:00:00"}]'
post resource  '[{"name":"workbench","location":"factory","maximum":1}]'
post operation '[{"name":"Make table","type":"time_per","item":"table","location":"factory","duration_per":"01:00:00"}]'
post operationmaterial '[
  {"operation":"Make table","item":"plank","quantity":-1,"type":"start"},
  {"operation":"Make table","item":"screw","quantity":-4,"type":"start"}]'
post operationresource '[{"operation":"Make table","resource":"workbench","quantity":1}]'
post demand "[
  {\"name\":\"order 1\",\"item\":\"table\",\"location\":\"factory\",\"customer\":\"customer A\",\"quantity\":100,\"due\":\"$(due 5)\",\"status\":\"open\"},
  {\"name\":\"order 2\",\"item\":\"table\",\"location\":\"factory\",\"customer\":\"customer A\",\"quantity\":100,\"due\":\"$(due 6)\",\"status\":\"open\"},
  {\"name\":\"order 3\",\"item\":\"table\",\"location\":\"factory\",\"customer\":\"customer A\",\"quantity\":100,\"due\":\"$(due 7)\",\"status\":\"open\"}]"
echo "登録が終わりました"
