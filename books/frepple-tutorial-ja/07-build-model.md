---
title: "最小のモデルを一から作る"
---

この章のゴール: 空のデータベースに、テーブル 1 種類の生産モデルを自分で登録し、計画を立てる。

:::message
**この章で学べる計画の考え方**

- 需要 → 部品表 → 工程 → リソース → 購買、というモデル化の順序
- 補充手段（作る・買う）がない品目は計画できない
- 能力が足りない状況を作ると、制約あり／なしの差がはっきり出る
:::

デモデータでは部品表(BOM)や工程がすでに入っていました。ここでは自分の手で入力し、frePPLe のデータモデル(「何をどこに登録すると、計画に何が起きるか」)を理解します。

## 作るモデル

**「テーブル」を 1 種類だけ作る小さな工場** を考えます。

```
[サプライヤー]--購買--> 板(plank) ---+
                                      +--> [作業台で組み立て] --> テーブル(table) --> 顧客の受注
[サプライヤー]--購買--> ねじ(screw) --+
```

- テーブル 1 個は、板 1 枚とねじ 4 本から作る。
- 組み立ては作業台(workbench)で 1 個あたり 1 時間かかる。作業台は 1 台で、同時に 1 個しか組み立てられない。
- 板は発注から 3 日、ねじは 1 日で届く。

受注は 3 件で、合計 300 個です。作業台は 1 日 24 時間使えるものとしても、300 個には 300 時間(12.5 日)かかります。**能力が足りない** ように、わざとこの設定にしています。06 章の制約あり計画を、自分で作ったデータで体験するためです。

## データを空にする

デモデータが残っていると混ざるので、いったん消します。

1. Admin メニューの **Execute** を開く。
2. 「Clear all data」のカードを開く。
3. 何も変えずに **Launch** を押す。

このカードは、既定で「DATA TABLES」（品目・受注・オーダーなどのデータ）だけにチェックが入っています。「ADMIN TABLES」（ユーザー、パラメータなど）にはチェックが入っていません。この状態のままにしてください。手元で確認すると、データテーブルは空になり、パラメータ（計画基準日 `currentdate` など）、期間の軸（バケット）、ユーザーは残りました。

:::message
デモデータを残したまま試したいときは、scenario2 などのシナリオの中で作業できます（10 章）。その場合、URL に `/scenario2` を付けます。
:::

## 計画基準日を確認する

Admin メニューの **Parameters** で `currentdate` を確認します。デモデータの読み込み後と同じく `today`（実行日）のままです。以降の受注の納期は、基準日からの日数で書くので、基準日を **D0** とします。

## データを登録する

登録の順番が大切です。**「参照される側」から先に** 登録します。メニューは、依存するデータがあるときにだけ現れる仕組みです(03 章の注意点)。

:::message
データ入力は、一覧画面のグリッド(表)で行を追加するか、`Excel/CSV のインポート` (公式ドキュメント `user-interface/getting-around/importing-data`)で一括して行えます。工程の所要時間(duration)などの期間は、API では `01:00:00`(1 時間)、`3 00:00:00`(3 日)の形式で入出力できることを確認しました。画面のグリッド（Operations）でも、`Duration Per Unit` は `01:00:00` と表示されます。詳しくは 公式ドキュメント `user-interface/data-maintenance` を参照してください。
:::

:::message
画面で 1 件ずつ入力する代わりに、次の登録をまとめて行うスクリプトを `examples/frepple-api/setup-model.sh` に置いています。公式ドキュメントにある REST API（`POST /api/input/…`）を呼ぶだけのものです。`./setup-model.sh` を実行すると、下の 1〜5 がすべて登録されます。画面で登録した場合は不要です。
:::

### 1. 拠点・顧客・品目

| Sales メニュー | 登録する内容 |
|---|---|
| Locations | `factory` |
| Customers | `customer A` |
| Items | `table`、`plank`、`screw` |

### 2. サプライヤーと調達条件

Purchasing メニューの **Suppliers** に `lumber shop` を登録します。続いて **Item suppliers** で、どの品目をどのサプライヤーから買えるかを登録します。

| item | location | supplier | leadtime |
|---|---|---|---|
| plank | factory | lumber shop | 3 日 |
| screw | factory | lumber shop | 1 日 |

(公式ドキュメント `model-reference/item-suppliers` の `leadtime` は調達リードタイムです。)

### 3. リソース(作業台)

Capacity メニューの **Resources** に登録します。

| name | location | maximum |
|---|---|---|
| workbench | factory | 1 |

`maximum` は同時に扱える量です(公式ドキュメント `model-reference/resources`)。1 なら、同時に 1 つの作業しかできません。

### 4. 工程(operation)と部品表(BOM)

Manufacturing メニューの **Operations** に、工程を登録します。

| name | type | item | location | duration per unit |
|---|---|---|---|---|
| Make table | time_per | table | factory | 1 時間 |

`time_per` は、数量に比例して時間がかかる工程です(公式ドキュメント `model-reference/operations`)。`item` は、この工程が作る品目です。

次に **Operation materials** で、材料の消費を登録します。**消費は負の数** で書きます (公式ドキュメント `model-reference/operation-materials`)。

| operation | item | quantity | type |
|---|---|---|---|
| Make table | plank | -1 | start |
| Make table | screw | -4 | start |

`table` を作る側(`end` で生産)は、工程の `item` から暗黙に決まるので、登録は不要です。

最後に **Operation resources** で、この工程が使うリソースを登録します。

| operation | resource | quantity |
|---|---|---|
| Make table | workbench | 1 |

### 5. 受注(demand)

Sales メニューの **Sales orders** に、3 件の受注を登録します。`due` は基準日 D0 からの日数で表します。

| name | item | location | customer | quantity | due |
|---|---|---|---|---|---|
| order 1 | table | factory | customer A | 100 | D0 + 5 日 |
| order 2 | table | factory | customer A | 100 | D0 + 6 日 |
| order 3 | table | factory | customer A | 100 | D0 + 7 日 |

`status` は `open` にします。`priority` は既定値(10)のままで構いません (公式ドキュメント `model-reference/sales-orders`)。

## 計画を立てる

まず制約なしで実行して、次に制約ありで実行します。

```bash
# 制約なし
./plan.sh "plantype=2&constraint=0&env=supply"

# 制約あり
./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply"
```

(Execute 画面の「Create a plan」から、4 章・6 章と同じ設定で実行してもかまいません。)

何が起きるかを予想してから、結果を見てください。以下は手元の環境で実測した値です。計画基準日は実行日（今日）なので、実行する日によって数値は少し変わります。

**制約なし計画**

| 見るところ | 結果 |
|---|---|
| problem report | workbench の `overload`(能力オーバー)が 1 件 |
| 製造オーダー | `Make table` が 100 個ずつ 3 件。作業台 1 台なのに、開始が 1 日ずつしかずれず、期間が重なっている |
| 購買オーダー | plank 300 枚、screw 1200 本の 2 件。**開始が過去の日付**(基準日の 3 日前)になっている |

**制約あり計画**

| 見るところ | 結果 |
|---|---|
| problem report | 問題なし(制約を守った計画なので) |
| 納品日 | order 1 は納期より 3 日遅れ、order 2 は 5 日遅れ、order 3 は 8 日遅れ |
| 製造オーダー | `Make table` が 26 件に分かれ、作業台が空く順に並ぶ |
| 購買オーダー | plank は合計 300 枚、screw は合計 1200 本。それぞれ 2 件に分かれ、いずれも未来の日付 |
| constraint report | 各受注に `overload`(workbench)、`manufacturing lead time`(Make table)、`purchasing lead time`(Purchase plank ...)が並ぶ |

Sales orders の一覧には **Delay** 列があり、納期に対する遅れが赤いセルで出ます（納品日は Delivery Date 列）。手元の 9.17.0 では、上の 3 件が「4 days」「6 days」「9 days」と表示されました。この列は、時刻まで含めて日数を切り上げるため、納品日の差（3 日・5 日・8 日）より 1 日大きく出ることがあります。制約あり計画で、後ろの受注ほど大きく遅れるのは、作業台が 1 台しかなく、順番に作るしかないためです。制約なしでは購買オーダーが過去の日付に出ますが、制約あり計画では板の到着(D0 + 3 日)を待ってから製造を始めます。

## 考えてみよう

- 板の入荷を遅くするとどうなるでしょうか。`leadtime` を 3 日から 10 日にして、制約あり計画をやり直してみましょう。手元の環境では納品が大きく遅れ、order 1 は納期より 9 日、order 3 は 15 日遅れになりました(D0 = 9/30 のとき)。constraint report の理由は、`overload` と `purchasing lead time` でした。
- 作業台を 2 台にする(`workbench` の `maximum` を 2 にする)と、遅れはどう変わるでしょうか。手元の環境では order 1 は 1 日遅れ、order 3 は 2 日遅れまで縮みました(D0 = 9/30 のとき)。能力を増やすと遅れは減りますが、ゼロにはなりませんでした。constraint report には引き続き `overload` が出ました。この理由は「ある時点で能力が足りなかった」ことを示し、最終的な遅れの大きさは表しません。

## つまずきポイント

- 受注のメニューが出てこない: item・location・customer のどれかが未登録です。
- 計画しても何も出ない: item の `table` に、補充する手段(工程の `item` が `table` で `location` が `factory`)が登録されているかを確認してください。problem report に「invalid data」が出ている場合は、補充手段が「ない」「多すぎる」のどちらかです。
- 購買オーダーが出ない: 「Generate supply plan」がオフではないか、item supplier の item と location が合っているかを確認してください。
- 所要時間の単位に迷う: `duration_per` は「1 個あたり」の時間です。`duration` は数量に関係ない固定の時間です。
