#!/bin/bash
# frePPLe の計画を、Web API(/execute/api/runplan/)で実行し、終わるまで待つ。
#
# 使い方:
#   ./plan.sh "plantype=2&constraint=0&env=supply"                       # 制約なし
#   ./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply"       # 制約あり
#   ./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply" scenario1   # シナリオの中で実行
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
. "$(dirname "$0")/common.sh"

use_scenario "$2"
run_task "/execute/api/runplan/?$1" 300
echo "task $tid: $st (${i}s)"
[ "$st" = "Done" ]
