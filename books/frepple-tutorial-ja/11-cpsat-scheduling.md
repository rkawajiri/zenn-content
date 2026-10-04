---
title: "発展: CP-SAT でスケジューリングする"
---

この章のゴール: Google OR-Tools の **CP-SAT** ソルバーで、frePPLe が出した製造オーダーのスケジュールを最適化する小さなプログラムを動かし、仕組みと限界を理解する。

:::message
**この章で学べる計画の考え方**

- 受注を 1 件ずつ計画するヒューリスティックと、全体を最適化する方法の違い
- リソース上の順序決めは、「重なり禁止」と「遅れ最小化」の制約付き最適化で書ける
- 外部の最適化結果を計画に戻すときは、再計画で上書きされる点と、上流・下流の整合に注意が要る
:::

:::message alert
この章は発展編です。frePPLe 本体には CP-SAT は組み込まれていません。外部のスクリプトが frePPLe から計画を読み、最適化し、結果を書き戻します。サンプルコードは `examples/cpsat/optimize.py` にあります。
:::

## CP-SAT とは

CP-SAT は、Google OR-Tools に含まれる制約プログラミングのソルバーです。「変数」「制約」「目的関数」を宣言すると、条件を満たす中で目的が最良になる解を探します。ジョブショップ型のスケジューリング(限られた機械に、順序を決めて仕事を割り当てる)が得意です。

frePPLe のソルバー(ヒューリスティック)は、受注を 1 件ずつ順番に計画するので、非常に高速です。その反面、全体最適になるとは限りません。CP-SAT を使うと、「機械が競合する部分だけ」を全体最適の視点で並べ直せます。

|  | frePPLe のソルバー | CP-SAT |
|---|---|---|
| 得意なこと | 部品表・在庫・購買を含む全体の計画 | リソース上の仕事の順序の最適化 |
| 計画の方法 | 受注を優先度順に 1 件ずつ計画 | 全体を数理モデルにして探索 |
| 速度 | 高速 | 問題の大きさ次第(時間制限を付けて使う) |

## このチュートリアルでの役割分担

1. frePPLe で計画を立てる。
2. 外部スクリプトが、frePPLe から製造オーダー(MO)を読む。
3. CP-SAT で、リソースが競合しないように、納期遅れが最小になる順序・開始時刻を求める。
4. `--apply` を付けた場合だけ、新しい開始・終了日時を frePPLe に書き戻す。

```
frePPLe --REST API の GET (読み取り)--> optimize.py --CP-SAT--> 新しいスケジュール
   ^                                                          |
   +---------- REST API の PATCH (書き戻し) <-----------------+
```

:::message
書き戻しは、frePPLe の REST API で製造オーダーを **PATCH**（一部の項目だけ更新）して行います。この動作は 9.17.0 で確認しました。9.18.0 以降では、この PATCH が失敗するため、この本では 9.17.0 を使っています（3 章）。原因と、確認した内容は、この章の最後のコラムに書きました。
:::

## どんな計画を入力にするか

CP-SAT の出番があるのは、**リソースが重なって使われている計画** です。かつ、部品の到着などのリードタイムは守られていてほしいので、入力には「能力だけ制約しない計画」を使います。

| 計画 | CP-SAT の入力として |
|---|---|
| 制約あり計画(06 章) | すでに能力を守っているので、CP-SAT で動かせるところがほとんどない |
| 制約なし計画(`--plantype=2`) | リソースが重なるが、購買オーダーが **過去の日付** に出る。部品が届く前に製造を始めることになり、実行できない |
| **能力だけ制約しない計画**(`--plantype=1 --constraint=mfg_lt,po_lt`) | リソースは重なるが、購買や製造は未来の日付。これを使う |

デモデータ（04 章）にも、同じ「能力だけ制約しない計画」（`plantype=1&constraint=mfg_lt,po_lt`）をかけると、能力オーバーが 7 件出て、`optimize.py` は 26 件の MO のうち 8 件の開始時刻を動かしました（手元の 9.17.0 での例です）。ただし、この本ではモデルが小さく結果を追いやすい 07 章のモデルを使います。なお、「制約なし計画」（`plantype=2`）を入力にすると、基準日より前に始まる MO が基準日まで押し出されるだけで、リソースの重なりの解消とは別の動きになります。

## 数理モデル

サンプルは、次のようなモデルです。

| 要素 | 内容 |
|---|---|
| 変数 | MO ごとの開始時刻(分単位の整数) |
| 所要時間 | 元の計画の `enddate - startdate`(固定) |
| 最早開始 | 元の `startdate` と計画基準日(`currentdate`)の遅いほう。前倒しはしない |
| リソース制約 | リソースごとに `AddNoOverlap`(同時に 1 件だけ) |
| 固定の占有 | confirmed / approved / completed の MO は動かさず、リソースを占有する区間として扱う |
| 目的関数 | 各 MO の遅れ(新しい終了 - 元の `enddate`)の合計を最小化 |

コードの中心は、次の部分です(全体は `optimize.py`)。

```python
for m in mos:
    due = to_min(m["end"])
    duration = max(1, due - to_min(m["start"]))
    release = to_min(max(m["start"], not_before)) if not_before else to_min(m["start"])
    start = model.NewIntVar(release, horizon, "s_" + m["reference"])
    end = model.NewIntVar(release + duration, horizon + duration, "e_" + m["reference"])
    interval = model.NewIntervalVar(start, duration, end, "i_" + m["reference"])
    for res in m["resources"]:
        per_resource[res].append(interval)          # リソースごとに区間を集める
    late = model.NewIntVar(0, horizon, "late_" + m["reference"])
    model.Add(late >= end - due)                   # 遅れ = max(0, 終了 - 納期)
    tardiness.append(late)

for intervals in per_resource.values():
    model.AddNoOverlap(intervals)                   # 同じリソースでは重ならない

model.Minimize(sum(tardiness))
```

## 準備

**1. Python の環境**

Python 3.9 以上が必要です。frePPLe とは別の仮想環境を作って、依存関係を入れます。

```bash
cd examples/cpsat
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**2. API の確認**

REST API は、Basic 認証(`admin` / `admin`)で呼べます (公式ドキュメント `integration-guide/rest-api/api-from-the-command-line`)。応答することを確認しましょう。

```bash
curl -u admin:admin "http://localhost:9000/api/input/manufacturingorder/?format=json&status=proposed" | head -c 600
```

製造オーダーが JSON で返ってくれば成功です。各オーダーには `startdate` `enddate` と、使うリソースを表す `resources` が含まれます。

:::message
`admin` のパスワードを変更している場合は、`--password` にその値を渡してください。シナリオの中で作業するときは、URL にシナリオ名を付けます(`--url http://localhost:9000/scenario2`)。
:::

## 実行する

07 章で作ったモデルを使います。デモデータを残したいときは、07 章の内容を scenario2 で作業してもかまいません。以下のコマンドは、07 章のモデルがある default のデータベースに対するものです。

**手順 1: 能力だけ制約しない計画を作る**

`plan.sh` は、4 章で紹介した `examples/frepple-api/plan.sh` です。

```bash
./plan.sh "plantype=1&constraint=mfg_lt,po_lt&env=supply"
```

問題レポートには、`workbench` の `overload`(能力オーバー)が出ます。製造オーダーは、同じ作業台で時間が重なっています。

**手順 2: まず計算だけする(書き戻さない)**

```bash
python optimize.py --url http://localhost:9000 --user admin --password admin
```

計画基準日(`currentdate`)は API から取得します。`currentdate` が `today` や `now` のときは、直近の計画実行で記録された `last_currentdate` を使います。取得できない場合は `--not-before "2026-09-30 00:00:00"` のように指定してください。

手元の環境では、次のように出力されました(日付や数値は実行した日で変わります)。

```
proposed MO: 5 件, 固定の占有区間: 0 件
開始の下限(計画基準日): 2026-09-30 00:00:00
CP-SAT: OPTIMAL, 遅れ合計 22080 分(元の enddate を納期とみなした値)
開始時刻が変わる MO: 4 件
  1: 2026-10-03 00:00:00 -> 2026-10-08 08:00:00
  3: 2026-10-03 20:00:00 -> 2026-10-11 08:00:00
  4: 2026-10-03 20:00:00 -> 2026-10-06 04:00:00
  5: 2026-10-04 20:00:00 -> 2026-10-05 00:00:00
--apply を付けると書き戻します
```

- `OPTIMAL`: 最適解が見つかった。`FEASIBLE` なら、時間制限内で見つけた最良解です。
- 「遅れ合計」が小さいほど、良いスケジュールです。
- 「開始時刻が変わる MO」が 0 件なら、そもそもリソースの競合がなかったということです。

**手順 3: 書き戻して、結果を見る**

```bash
python optimize.py --url http://localhost:9000 --user admin --password admin --apply --status approved
```

Manufacturing メニューの **Manufacturing orders** で、開始時刻が動いたこと、Capacity メニューの **Resource detail** で、作業台の上でオーダーが順番に並んでいることを確認してください。手元では、書き戻した後の製造オーダー 5 件は、時間が重なる組が 0 件になり、作業台の上で順番に並びました。

`--status approved` を付けたのは、書き戻した MO を次の `runplan` で消されないようにするためです。付けない場合は `proposed` のままで、再計画すると作り直されます。

**手順 4: 再計画してみる**

```bash
./plan.sh "plantype=1&constraint=mfg_lt,po_lt&env=supply"
```

手元では、`approved` にした製造オーダー 5 件は、日時が変わらずに残りました。frePPLe は、それらを動かせない入力として扱い、購買オーダーなど周りを計画し直します。

## サンプルの動作確認

frePPLe に接続しなくても、最適化部分だけは手元で試せます。次のコードは、2 件の MO が同じ `saw` を使う、最小のケースです。

```python
from datetime import datetime as D
from optimize import solve

t = D(2021, 1, 4, 8)
mos = [
    {"reference": "A", "start": t, "end": D(2021, 1, 4, 10), "resources": ["saw"]},  # 2時間
    {"reference": "B", "start": t, "end": D(2021, 1, 4, 9),  "resources": ["saw"]},  # 1時間
]
print(solve(mos))
```

CP-SAT は、先に短い `B` を置いて、次に `A` を置きます(遅れ合計は `B` が 0 分、`A` が 60 分)。逆に置くと、遅れは `B` が 120 分になり、合計が大きくなるためです。

## この方式の限界(重要)

このサンプルは、CP-SAT を使うイメージをつかむためのもので、そのまま本番には使えません。

| 限界 | 内容と対策 |
|---|---|
| 再計画で上書きされる | `runplan` は proposed のオーダーを作り直します(公式ドキュメント `model-reference/manufacturing-orders`)。書き戻した結果を残したいなら、status を `approved` か `confirmed` にします (08 章)。ただし `confirmed` にすると frePPLe は動かせなくなります。 |
| 工程の前後関係 | MO 同士の前後関係(部品の MO → 組立の MO)を考慮していません。上流の MO を遅らせると、下流の MO が部品なしで始まることになりかねません。ペギング（MO の `plan` にある情報）を使って前後関係の制約を足す必要があります。 |
| 在庫・購買との整合 | 在庫の推移、問題レポート、制約レポートは、frePPLe の計画エンジンが出力するときに作られます。外部で日時を変えると、それらとずれます。書き戻した後に `runplan` を再実行すると、`approved` に固定した MO を入力として、購買などを計算し直せます。 |
| カレンダー・段取り | 稼働カレンダー、段取り(setup)、スキル、代替リソースは考慮していません。所要時間は `enddate - startdate` の経過時間として固定しています。 |
| 前倒しはしない | 開始は元の `startdate` より前にはしません。部品が届く時刻を保証するためです。 |

:::message
この例では、CP-SAT の結果は、frePPLe の制約あり計画とほぼ同じ時期に終わりました (最後の製造オーダーの終了が、どちらも基準日の 15〜16 日後)。このモデルは単純なので、frePPLe のソルバーもほぼ最適な並びを見つけているためです。CP-SAT が効くのは、段取り替えの時間、受注ごとの重み、複数リソースの同時占有など、目的や制約が複雑になったときです。
:::

## 発展: frePPLe の一部として組み込む

外部スクリプトの次の段階として、frePPLe の計画実行の流れの中に組み込む方法があります。

- **管理コマンドにする**: `management/commands/` に Django のコマンドとして置くと、Execute 画面のボタンや `frepplectl`、Web API から実行できるようになります (公式ドキュメント `developer-guide/creating-an-extension-app`)。この方法なら、外部から REST API を呼ばず、frePPLe の内部で直接データを更新できます。
- **計画タスク(PlanTask)にする**: `freppledb/common/commands.py` の `PlanTask` として登録すると、`runplan` の一部として実行されます。供給計画(順序 200)とエクスポート(順序 401)の間に挟めば、CP-SAT の結果がそのまま計画として出力されます。この方式では、frePPLe の実行環境に `ortools` を入れる必要があります。

これらは、frePPLe の内部の構造に手を入れることになります。まずは、この章の外部スクリプトで効果を確かめてから検討するのがおすすめです。

## 練習問題

1. `solve()` の目的関数を、遅れの合計から「最後の MO の終了時刻(makespan)の最小化」に変えてみましょう。
2. 受注の優先度(08 章)を、遅れに掛ける重みとして使うには、どう変えればよいでしょうか。
3. 2 つの MO に前後関係(A が終わってから B を始める)を加えるには、`model.Add(start_B >= end_A)` をどこに足せばよいでしょうか。

## コラム: 9.18 以降の REST API の不具合

3 章で 9.17.0 に固定した理由です。9.18.1 で確認した内容を、記録として残します。

**製造オーダーの PATCH が失敗する（HTTP 500）**

`PATCH /api/input/manufacturingorder/<番号>/` で日時を更新しようとすると、`Direct assignment to the reverse side of a related set is prohibited` というエラーになります。原因は、9.18.0 で REST API の内部が `djangorestframework-bulk` から `django-bulk-drf` 0.2.91 に替わったことにあります。

- 更新のとき、ライブラリの `operations.py`（`_apply_updates`）が、送られた項目を `setattr(instance, field, value)` で 1 つずつ代入します。
- 製造オーダーには `resources` と `materials` という「逆向きの関連」の項目があり、しかも必須です。これに値を代入すると、Django が拒否します。
- 確認のため、コンテナ内でこの代入を「逆向きの関連なら飛ばす」1 行の修正を入れたところ、PATCH が成功しました（確認後、元に戻しました）。

サーバーのログ（Apache の error.log）には「Internal Server Error」の 1 行しか出ず、トレースバックは残りません。トレースバックは、コンテナの中で Django のシェルから同じリクエストを送り、エラーを整形する直前で出力させて得ました。

**受注の PATCH も、一部の項目だけでは失敗する**

PATCH なのに部分更新として扱われず、必須項目（`item`、`customer`、`location`、`due`、`quantity`）を全部送らないと、HTTP 500 になります。全部送れば成功します。公式ドキュメントには、一部の項目だけを送る PATCH の例があるので、ドキュメントの動作とも合いません。

**9.17.0 では**

どちらも成功します。受注は `priority` だけ、製造オーダーは開始・終了日時だけを送れば更新できました。

この不具合は、2026-09-30 時点で、frePPLe の GitHub の issue には見当たりませんでした。最新の版で試すときは、まず製造オーダーの PATCH が通るかを確かめてください。

## つまずきポイント

- `ModuleNotFoundError: ortools`: 仮想環境が有効か、`pip install -r requirements.txt` を実行したかを確認してください。
- `401` や `403` が返る: `--user` と `--password` を確認してください。REST API は Basic 認証で呼んでいます。
- 書き戻しで HTTP 500 が返る: frePPLe の版が 9.18.0 以降ではありませんか。この本は 9.17.0 で確認しています（3 章、この章のコラム）。
- `proposed MO: 0 件`: 計画を実行したか、`status` が proposed のオーダーがあるかを確認してください。
- 結果が `INFEASIBLE` になる: 固定の占有区間どうしが重なっているなど、データに矛盾がある可能性があります。
- 実行に時間がかかる: `--time-limit` で探索時間の上限を指定してください。
