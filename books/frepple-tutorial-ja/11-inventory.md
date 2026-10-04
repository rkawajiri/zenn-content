---
title: "在庫の目標と補充の単位"
---

この章のゴール: 現在庫・安全在庫・発注の最小と倍数を設定して、在庫の持ち方が購買と製造の計画にどう効くかを確認する。Community にない「在庫計画」が何をする機能かも知る。

:::message
**この章で学べる計画の考え方**

- 現在庫があれば、その分は作らない・買わない（正味所要量）
- 安全在庫は、需要に加えて「手元に残しておきたい量」を計画に足す
- 発注の最小・倍数は、必要な量より多く買わせる。在庫が増える原因になる
- 在庫の目標を自動で決める「在庫計画」は、Community にはない
:::

在庫は、品目と拠点の組み合わせ（バッファ、`buffer`）ごとに持ちます。5 章のモデルでは、バッファを登録していません（Buffers は空でした）。登録しなくても計画はできます。公式ドキュメントでは、現在庫（`onhand`）と安全在庫（`minimum`）の既定値は 0 です。

:::message alert
この章は、5 章のモデルだけがある状態から始めます。8 章と 10 章でデータを変えているので、**5 章の「データを空にする」を実行し、`examples/frepple-api/setup-model.sh` で登録し直してから** 進めてください（`setup-distribution.sh` は実行しません）。数値は、その状態で実測した値です。シナリオ（9 章）の中で作業してもかまいません。
:::

## 在庫の設定は 3 か所にある

| 設定 | 場所 | 意味 |
|---|---|---|
| 現在庫（`onhand`） | Inventory メニューの **Buffers**（`/data/input/buffer/`） | 計画の開始時点の在庫量 |
| 安全在庫（`minimum`） | 同じ Buffers | 手元に残しておきたい最小の在庫量 |
| 発注の最小・倍数（`sizeminimum`・`sizemultiple`） | Purchasing メニューの **Item suppliers** | 1 回の発注量の下限と、単位 |

公式ドキュメント `model-reference/buffers` によると、`minimum` は **ソフトな制約** です。計画エンジンはその水準を保とうとしますが、受注を満たすために必要なら、下回ることを許します。下回ると、問題として報告されます。

バッファの登録は、画面の Buffers で行を足すか、API で行えます。

```bash
curl -u admin:admin -H "Content-Type: application/json" -X POST \
  "http://localhost:9000/api/input/buffer/?format=json" \
  -d '[{"item":"table","location":"factory","onhand":120}]'
```

## 実験 1: 現在庫があるとどうなるか

`table` を `factory` に 120 個持っているとします。登録したら、制約あり計画をやり直します。

```bash
./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply"
```

手元では、次のようになりました。

| | 製造（MO）の合計 | 購買（PO）の合計 | 納品日（現在庫なしとの差） |
|---|---|---|---|
| 現在庫なし（7 章） | 300 個 | plank 300 枚、screw 1200 本 | — |
| **現在庫 120 個** | 180 個 | plank 180 枚、screw 720 本 | order 1 が 3 日、order 2 が 5 日、order 3 が 5 日早い |

受注は合計 300 個です。120 個は在庫から出せるので、作るのは残りの 180 個になり、部品の購買もその分だけに減りました。作業台の負荷が減った分、納品も早まります。

## 実験 2: 安全在庫を足すとどうなるか

次に、`minimum`（安全在庫）を 50 個にします。Buffers で `Minimum` を書き換えるか、API で変更します。

```bash
# id は Buffers の一覧か、GET /api/input/buffer/ で確認する
curl -u admin:admin -H "Content-Type: application/json" -X PATCH \
  "http://localhost:9000/api/input/buffer/<id>/?format=json" -d '{"minimum":50}'
```

| | 製造（MO）の合計 | 購買（PO）の合計 | 納品日（現在庫なしとの差） |
|---|---|---|---|
| 現在庫 120、安全在庫 50 | 230 個 | plank 230 枚、screw 920 本 | order 1 が 3 日、order 2 が 4 日、order 3 が 3 日早い |
| 現在庫 0、安全在庫 50 | 350 個 | plank 350 枚、screw 1400 本 | order 1 は同じ、order 2 が 1 日、order 3 が 2 日遅い |

製造数量は「受注 300 − 現在庫 + 安全在庫」になりました（120 個あるとき 300 − 120 + 50 = 230、0 個のとき 300 + 50 = 350）。安全在庫は、需要とは別に「残しておく分」を計画に足します。在庫が 0 のときに安全在庫を持たせると、手元に残す 50 個を作る分が、受注分と作業台を取り合うためか、order 2・3 が遅れました（原因までは調べていません）。

## 実験 3: 発注の最小・倍数

plank を買うときの item supplier に、`sizeminimum` を 200、`sizemultiple` を 100 にします。現在庫と安全在庫は 0 に戻しておきます。

```bash
curl -u admin:admin -H "Content-Type: application/json" -X PATCH \
  "http://localhost:9000/api/input/itemsupplier/<id>/?format=json" \
  -d '{"sizeminimum":200,"sizemultiple":100}'
```

手元では、plank の購買が **200 枚ずつ 2 件（合計 400 枚）** になりました。必要なのは 300 枚なので、100 枚が余ります。製造の件数と納品日は変わりませんでした。

:::message
ここまでの実験のあと、バッファと item supplier の設定は元に戻してください（バッファを削除し、`sizeminimum` を 1、`sizemultiple` を空にする）。
:::

発注の最小・倍数は、サプライヤーの都合（最小ロット）を表す設定です。必要量ぴったりに買えないとき、余りは在庫になります。

## 在庫計画（Community にない機能）

ここまでの設定は、安全在庫の水準を **人が決めて入力** するものでした。frePPLe の公式ドキュメントには、在庫計画（inventory planning）の機能があります。次のような機能です。

- 欲しいサービスレベル（欠品しない確率）から、安全在庫を **自動で計算する**
- 経済的な発注量（コストをもとにした式）から、発注量を自動で計算する
- 安全在庫や発注量に、最小・最大（数量、または何日分か）を設ける
- 品目×拠点を「セグメント」にまとめて、方針（policy）を一括で適用する

こうした設定は、Inventory policies という表に入れます（公式ドキュメント `modeling-wizard/inventory-planning/inventory-planning-parameters`）。

この機能は、Community の 9.17.0 には入っていません。確認できたのは次のとおりです。

- 有効なアプリの一覧（`INSTALLED_APPS`）に、在庫計画のアプリがない
- 在庫計画の画面の URL（`/inventoryplanning/`）が、存在しないページと同じ動き（トップへ戻る）になる
- 公式サイトの editions ページが、在庫計画の最適化を Cloud の追加機能として挙げている

Community で近いことをするなら、この章の方法（バッファの `minimum`、item supplier の最小・倍数）で、安全在庫と発注量を人が決めます。サービスレベルから逆算する計算は、この本では扱いません。

## つまずきポイント

- 現在庫を登録しても計画が変わらない: `item` と `location` が、受注や工程のものと一致しているかを確認してください。
- Buffers に行が出ない: 5 章のモデルでは、バッファは空のままで計画できます。現在庫や安全在庫を決めたい品目だけ、自分で登録します。
- 安全在庫を設定したのに、在庫が下回る: `minimum` はソフトな制約です。公式ドキュメントでは、受注を満たすために必要なら下回り、そのときは問題として報告される、と説明されています。
- 発注量が必要量より多い: item supplier の `sizeminimum` と `sizemultiple` を確認してください。
