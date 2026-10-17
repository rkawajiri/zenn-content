# plan.sh・reset-model.sh・setup-*.sh が共通で使う設定と関数。各スクリプトから source で読み込む。
#
# 環境変数: FREPPLE_URL(既定 http://localhost:9000)、FREPPLE_USER(既定 admin:admin)
URL=${FREPPLE_URL:-http://localhost:9000}
USER=${FREPPLE_USER:-admin:admin}

# request <シナリオ名(空なら default)> <curl の引数...>
# $URL にシナリオ名を付けた URL を P に入れて curl を実行し、本文を resp に入れる。
# HTTP の応答コードが 2xx でなければ、原因を表示して終了する。
# 例: request "$SCENARIO" -X POST "/execute/api/runplan/?..."(パスは最後の引数に書く)
request() {
  local scenario=$1; shift
  P=${scenario:+/$scenario}
  local path=${!#}
  local status code
  resp=$(curl -s -u "$USER" -w '\n%{http_code} %{redirect_url}' "${@:1:$#-1}" "$URL$P$path")
  status=${resp##*$'\n'}
  resp=${resp%$'\n'*}
  code=${status%% *}
  case "$code:$status" in
    401:*|302:*/login/*) echo "失敗: 認証できません(HTTP $code)。パスワードを変えたときは FREPPLE_USER=admin:<パスワード> を指定してください"; exit 1 ;;
    302:*|404:*) echo "失敗: シナリオ ${scenario:-default} が見つかりません(HTTP $code)。シナリオの名前と、使用中になっているかを確認してください"; exit 1 ;;
    000:*) echo "失敗: $URL に接続できません。frePPLe のコンテナが起動しているか確認してください"; exit 1 ;;
    2??:*) ;;
    *) echo "失敗: $URL$P$path から HTTP $code が返りました"; exit 1 ;;
  esac
}

# run_task <シナリオ名> <パスとクエリ> <待つ秒数の上限>
# Web API でタスクを起動し、終わるまで待つ。状態を st、task id を tid、かかった秒数を i に入れる。
run_task() {
  request "$1" -X POST "$2"
  tid=$(echo "$resp" | python3 -c "import sys,json;print(json.load(sys.stdin)['taskid'])" 2>/dev/null) ||
    { echo "起動に失敗: task id を受け取れません: $resp"; exit 1; }
  for i in $(seq 1 "$3"); do
    st=$(curl -s -u "$USER" "$URL$P/execute/api/status/?id=$tid" |
      python3 -c "import sys,json;d=json.load(sys.stdin);print(d[sys.argv[1]]['status'])" "$tid" 2>/dev/null)
    case "$st" in
      Done|Failed|Canceled) break ;;
    esac
    sleep 1
  done
}

# post <モデル名> <JSON>: REST API でデータを登録する。登録先のシナリオは P(request が設定する)。
post() {
  code=$(curl -s -u "$USER" -H "Content-Type: application/json" -X POST \
    "$URL$P/api/input/$1/?format=json" -d "$2" -o /tmp/frepple_setup.out -w "%{http_code}")
  printf '%-20s %s\n' "$1" "$code"
  [ "$code" = "201" ] || { cat /tmp/frepple_setup.out; echo; exit 1; }
}

# 納期は「今日」からの日数で作る
due() { python3 -c "from datetime import date,timedelta;print((date.today()+timedelta(days=$1)).isoformat()+'T00:00:00')"; }
