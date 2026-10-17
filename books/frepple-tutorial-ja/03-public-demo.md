---
title: "公開デモで4つの領域を見て回る"
---

この章のゴール: インストールなしで、公開されている frePPLe のデモを開き、2 章で見た 4 つの領域（Forecast / Inventory / Distribution / Production）が、実際の画面ではどう見えるかを先に知っておく。

:::message
**この章で学べる計画の考え方**

- 計画システムの出力は、需要・在庫・配送・製造・購買のオーダーとして、領域ごとの画面で見る
- 「計画が完成した状態」を先に見ておくと、以降の章で何を作るのかが分かる
:::

## 公開デモとは

frePPLe の開発元は、ブラウザだけで触れるデモ環境を公開しています。

- https://demo.frepple.com/

開くと、ログインの画面は出ず、そのまま管理者（Admin）としてホーム画面が表示されました（2026-10-04 に確認）。

:::message alert
公開デモは **誰でも使える共有の環境** です。ほかの人も同じデータを見ています。この本では、データを変えたり計画を実行したりせず、**見るだけ** にとどめます。データの変更や計画の実行が許されているかは、確認していません。
:::

:::message
公開デモは、この本で使う Community Edition ではなく、**Enterprise Edition 相当** の画面です（画面左上のロゴに表示される版は 9.18.0 でした）。在庫計画や対話的なガント（Plan editor）など、Community にない機能が入っています。4 章以降で自分の手元に立てる環境とは、画面や機能が少し違います。内容は、時期によって変わる可能性があります。
:::

## ホーム画面

ホーム画面は、計画の状況を並べたウィジェットの集まりです。実行済みの計画のタスク、予測（FORECAST）と予測誤差（FORECAST ERROR）、製造・配送・購買オーダーの件数など、4 つの領域の結果が 1 画面に集まっています。

メニューは上部に並びます。sales / inventory / capacity / purchasing / manufacturing / admin の順です。以降の見学は、このメニューから開くか、URL を直接入力します。

## 見てみよう 1: Forecast（需要予測）

Sales メニューの **Forecast report**（`/forecast/`）を開きます。

- https://demo.frepple.com/forecast/

![公開デモの Forecast report。品目・顧客・拠点ごとに、期間別の予測の数量が並ぶ](/images/frepple-tutorial-ja/demo-forecast.jpg)

行は「品目 @ 拠点 @ 顧客」の組み合わせ、列は期間（月など）です。`All items @ All locations @ All customers` のように、上位にまとめた行もあります。過去の受注から作った統計予測が、将来の期間に並んでいます。予測の仕組みは 13 章で自分の手元で確かめます。

## 見てみよう 2: Inventory（在庫と在庫計画）

Inventory メニューの **Inventory planning**（`/inventoryplanning/drp/`）を開きます。

- https://demo.frepple.com/inventoryplanning/drp/

![公開デモの Inventory planning。品目×拠点ごとに、在庫の状態・安全在庫・発注量・現在庫などが並ぶ](/images/frepple-tutorial-ja/demo-inventory-planning.jpg)

品目×拠点ごとに、現在庫（On Hand）、安全在庫（Safety Stock）、発注量（Reorder Quantity）、未処理の受注、提案中のオーダーなどが 1 行に並びます。この画面は Community にはありません。サービスレベルから安全在庫を自動で計算する機能の画面です。Community では、安全在庫を自分で決めて入力します（11 章）。

Inventory メニューの **Inventory report**（`/buffer/`）は Community にもあり、品目×拠点の在庫の推移が見られます（6 章）。手元の日本語表示では、メニュー名は「在庫」、画面名は「棚卸レポート」です。

## 見てみよう 3: Distribution（拠点間の配送）

Inventory メニューの **Distribution order summary**（`/distribution/`）を開きます。

- https://demo.frepple.com/distribution/

![公開デモの Distribution order summary。品目と出発地・配送先ごとに、期間別の配送数量が並ぶ](/images/frepple-tutorial-ja/demo-distribution.jpg)

`chair` の `factory` → `warehouse`、`warehouse` → `shop 1`、`warehouse` → `shop 2` のように、品目と、出発地・配送先の組み合わせごとに、期間別の配送数量が並びます。工場 → 倉庫 → 店舗の 2 段の配送網です。自分で配送を設定するのは 10 章です。

## 見てみよう 4: Production（製造・購買）

### ガントチャート（Plan editor）

次の URL を開きます。

- https://demo.frepple.com/planningboard/

![公開デモの Plan editor（Manufacturing シナリオ）。行がリソース、横軸が時間、四角が製造オーダー](/images/frepple-tutorial-ja/demo-plan-editor.jpg)

- 行はリソース（assembly line、grinder、saw、Carl、Antonio）、横軸は時間、四角いバーは製造オーダーです。
- バーの色は遅れの大きさを表します。既定は「Color By Delay」で、メニューには feasibility、criticality、due date、priority などもあります。

Enterprise 版では、このバーをドラッグして計画を動かせます。共有環境なので、この本では試しません。Community にはこの画面がなく、12 章で扱う閲覧専用のガントチャートを使います。

### 優先度の例

画面右上のシナリオを選ぶドロップダウンには、機能ごとの小さな例（Example …）が 25 個以上あります。代替材料、稼働カレンダー、需要の優先度、make to order、リソースの代替・スキル・段取り、需要予測のいくつかの方法などです。「シナリオ」は、データベースを丸ごとコピーした独立したデータセットです（9 章で扱います）。

需要の優先度の例を開きます。

- https://demo.frepple.com/demand-priorities/data/input/demand/

![公開デモの Example demand priorities。優先度 1〜3 の受注が 12 件並び、Delay 列に遅れが色で出る](/images/frepple-tutorial-ja/demo-demand-priorities.jpg)

- 「Sales orders」の一覧に、優先度（Priority）が 1〜3 の受注が 12 件あります。
- 「Delay」の列に、納期に対する遅れが赤やオレンジのセルで出ています。
- 資源が足りないとき、優先度の高い受注ほど先に割り当てられます（8 章で自分の手元で試します）。

この日付の書式は、デモでは「日-月-年」（例: 04-12-2019）です。手元の環境（4 章以降）は「年-月-日」なので、見え方が少し違います。

同じ形の URL で、ほかの例も開けます。たとえば `/operation-posttime/data/input/operation/`（工程の後処理時間）や `/resource-alternate/data/input/resource/`（リソースの代替）です。これらの URL は、frePPLe の公式ドキュメント（`doc/examples/`）に載っています。

## 公開デモでできないこと

自分でデータを一から作ったり、条件を変えて何度も計画をやり直したりするには、共有のデモは向きません。次の章から、Docker で自分の手元に frePPLe を立てて、それを行います。

## つまずきポイント

- 画面が開かない・遅い: 共有の環境です。時間をおいて開き直してください。
- 数字や日付が本文と違う: デモのデータは、時期によって変わります。
- 画面の表記が英語: デモの言語設定は英語でした。この章の画面名は、デモの英語表記のまま書いています。4 章以降の手元の環境は日本語表示で、メニューは 販売（sales）/ 在庫（inventory）/ 能力（capacity）/ 購入（purchasing）/ 製造（manufacturing）/ 管理（admin）の順です。
