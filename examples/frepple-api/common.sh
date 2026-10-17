# plan.sh・reset-model.sh・setup-*.sh が共通で使う設定と関数。各スクリプトから source で読み込む。
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
URL=${FREPPLE_URL:-http://localhost:9000}
AUTH=${FREPPLE_USER:-admin:admin}

# use_scenario <シナリオ名(空なら default)>: 以降のリクエストの送り先を決める
use_scenario() {
  SCENARIO=${1:-default}
  P=${1:+/$1}
}

# request <curl の引数...> <パス>
# $URL にシナリオ名を付けた URL へ curl でリクエストし、本文を resp、HTTP の応答コードを code に入れる。
# 2xx でなければ、原因を表示して終了する。
request() {
  local path=${!#}
  local status
  resp=$(curl -s -u "$AUTH" -w '\n%{http_code} %{redirect_url}' "${@:1:$#-1}" "$URL$P$path")
  status=${resp##*$'\n'}
  resp=${resp%$'\n'*}
  code=${status%% *}
  case "$code:$status" in
    401:*|302:*/login/*) echo "失敗: 認証できません(HTTP $code)。パスワードを変えたときは FREPPLE_USER=admin:<パスワード> を指定してください"; exit 1 ;;
    302:*|404:*) echo "失敗: シナリオ $SCENARIO が見つかりません(HTTP $code)。シナリオの名前と、使用中になっているかを確認してください"; exit 1 ;;
    000:*) echo "失敗: $URL に接続できません。frePPLe のコンテナが起動しているか確認してください"; exit 1 ;;
    2??:*) ;;
    *) echo "失敗: $URL$P$path から HTTP $code が返りました"; echo "$resp"; exit 1 ;;
  esac
}

# run_task <パスとクエリ> <待つ秒数の上限>
# Web API でタスクを起動し、終わるまで待つ。状態を st、task id を tid、かかった秒数を i に入れる。
run_task() {
  request -X POST "$1"
  tid=$(echo "$resp" | python3 -c "import sys,json;print(json.load(sys.stdin)['taskid'])" 2>/dev/null) ||
    { echo "起動に失敗: task id を受け取れません: $resp"; exit 1; }
  for i in $(seq 1 "$2"); do
    st=$(curl -s -u "$AUTH" "$URL$P/execute/api/status/?id=$tid" |
      python3 -c "import sys,json;d=json.load(sys.stdin);print(d[sys.argv[1]]['status'])" "$tid" 2>/dev/null)
    case "$st" in
      Done|Failed|Canceled) break ;;
    esac
    sleep 1
  done
}

# post <モデル名> <JSON>: REST API でデータを登録する
post() {
  request -H "Content-Type: application/json" -X POST -d "$2" "/api/input/$1/?format=json"
  printf '%-20s %s\n' "$1" "$code"
}

# 納期は「今日」からの日数で作る
due() { python3 -c "from datetime import date,timedelta;print((date.today()+timedelta(days=$1)).isoformat()+'T00:00:00')"; }
