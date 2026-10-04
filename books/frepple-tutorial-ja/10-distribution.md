---
title: "拠点間の配送を設計する"
---

この章のゴール: 5 章のモデルに倉庫を足し、工場から倉庫への輸送を登録して、配送オーダー（DO）が出ることと、輸送のリードタイムが納品日に効くことを確認する。

:::message
**この章で学べる計画の考え方**

- 補充手段は「作る」「買う」に加えて「運ぶ」がある
- 輸送にもリードタイムと、運ぶ単位（ロット）がある
- 拠点が増えても、工場の能力は共有される。倉庫向けの受注の遅れは、輸送ではなく工場の能力が原因になりうる
:::

5 章のモデルは、拠点が工場 1 つだけでした。ここでは倉庫（warehouse）を足し、「工場で作ったテーブルを倉庫へ運んで、倉庫の顧客に届ける」流れを作ります。

配送の設定を持つデモデータは、12 章で見ます。

## 5 章のモデルに倉庫を足す

:::message alert
この章は、5 章のモデルだけがある状態から始めます。8 章で優先度、製造オーダーの status、リソースの `maximum` などを変えているので、**5 章の「データを空にする」を実行し、`examples/frepple-api/setup-model.sh` で登録し直してから** 進めてください（または、scenario2 などのシナリオの中で作業します。9 章）。
:::

足すのは次の 4 つです。画面で登録する代わりに、`examples/frepple-api/setup-distribution.sh` で、まとめて登録できます。

```bash
cd examples/frepple-api
./setup-distribution.sh
```

| 登録するもの | 内容 |
|---|---|
| 拠点（location） | `warehouse` |
| 顧客（customer） | `customer B` |
| 配送（item distribution） | 品目 `table`、配送先 `warehouse`、出発地 `factory`、リードタイム 2 日、倍数 10 |
| 受注（demand） | `order 4`: `table` 50 個、配送先 `warehouse`、顧客 `customer B`、納期は基準日の 10 日後、`status` は `open` |

:::message
REST API の項目名は、画面や公式ドキュメントと少し違います。9.17.0 の API では、配送先は `location`、最小・倍数は `sizeminimum`・`sizemultiple` です（公式ドキュメントの `model-reference/item-distributions` では `destination`、`size_minimum`、`size_multiple`）。
:::

登録の順番は、5 章と同じく「参照される側」から先です。拠点（`warehouse`）より先に配送を登録しようとすると、API は `Invalid pk "<拠点名>" - object does not exist.` のように拒否します。

## 計画を立てる

7 章と同じ設定の制約あり計画で実行します。

```bash
./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply"
```

結果を見ます。以下は、手元の環境で実測した値です。計画基準日が実行日なので、日付は実行する日で変わります。

| 見るところ | 結果 |
|---|---|
| 配送オーダー（DO） | `factory` → `warehouse`、`table` が 10 個ずつ 5 件（合計 50 個） |
| 製造オーダー（MO） | 合計 350 個（5 章の 300 個に、倉庫向けの 50 個が加わった） |
| 購買オーダー（PO） | plank 350 枚、screw 1400 本 |
| `order 4` の納品 | 倉庫で 10 個ずつ 5 回に分かれ、**納期より約 10 日遅れ** |

倉庫向けの 50 個も、材料の購買から始まって、工場で製造し、倉庫へ運ぶ、という流れで計画されました。Manufacturing メニューの Manufacturing orders と、Inventory メニューの Distribution order summary を見比べてみましょう。手元では、倉庫向けの MO は 10 個ずつ（作業台で 10 時間ずつ）で、**DO の開始時刻は、対応する MO の完了時刻と一致** していました。作り終えたものから、すぐ運び始める計画です。

## 遅れの理由を調べる

`order 4` が遅れた理由を、constraint report で見ます（7 章）。手元では 2 行でした。

| 理由 | 対象 |
|---|---|
| `overload` | `workbench`（作業台の能力不足） |
| `purchasing lead time` | `Purchase plank @ factory from lumber shop` |

**輸送は理由に出ていません。** 倉庫向けの受注も、工場の作業台 1 台を、order 1〜3 と取り合います。拠点を増やしても、能力の制約は元の工場に残ります。

## 輸送のリードタイムを変えてみる

item distribution のリードタイムを 2 日から 5 日にして、制約あり計画をやり直します。画面の Item distributions で `Lead time` を書き換えるか、API で変更します。

```bash
# id は Item distributions の一覧か、GET /api/input/itemdistribution/ で確認する
curl -u admin:admin -H "Content-Type: application/json" -X PATCH \
  "http://localhost:9000/api/input/itemdistribution/<id>/?format=json" \
  -d '{"leadtime":"5 00:00:00"}'
./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply"
```

手元では、`order 4` の納品日が **ちょうど 3 日後ろ** にずれました（2 日 → 5 日）。DO の件数（5 件）は変わりませんでした。確認できたら、リードタイムを 2 日に戻してください。

## 考えてみよう

- 倉庫の受注 `order 4` の優先度（`priority`）を 1 にして（既定は 10。小さいほど優先）、制約あり計画をやり直してみましょう（8 章）。手元では、`order 4` の納品が納期どおり（約 10 日早まる）になり、代わりに order 1〜3 の納品が 2 日ずつ遅れました。工場の能力は共有なので、誰かを先にすれば、誰かが後ろになります。
- 輸送にも能力の制約を付けるには、item distribution の `resource` と `resource_qty` を使います（公式ドキュメント `model-reference/item-distributions`）。この本では試していません。

## つまずきポイント

- 倉庫の受注が計画されない: item distribution の `item`、`location`（配送先）、`origin`（出発地）が受注と合っているかを確認してください。
- DO が出ない: item distribution の `priority` が 0 だと、計画で自動では使われません（公式ドキュメント）。
- DO の件数が思ったより多い、または少ない: 倍数（`sizemultiple`）、最小（`sizeminimum`）、`batchwindow` が影響します。
- 登録で `Invalid pk ... does not exist` と出る: 参照先の拠点・品目が未登録です。登録の順番を確認してください。
