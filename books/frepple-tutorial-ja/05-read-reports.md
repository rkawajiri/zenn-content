---
title: "レポートの読み方"
---

この章のゴール: 生成された計画を、各レポートで読み解けるようになる。

:::message
**この章で学べる計画の考え方**

- 計画は、需要・在庫・能力・例外の 4 つの視点で検証する
- 供給経路をたどると、ある品目がどこから来るかが分かる
:::

04 章で作った「制約なし計画」の結果を使います。まだ実行していない場合は、04 章に戻ってください。

:::message
メニュー名は画面の言語設定によって変わります。ここでは英語表記で書きます。括弧内は URL です。メニューから迷ったら、URL を直接ブラウザに入力しても開けます (`http://localhost:9000` に続けて入力します)。
:::

## レポートの一覧

| レポート | URL | 分かること |
|---|---|---|
| demand report | `/demand/` | 受注(需要)ごとの、納品量・遅れ・不足 |
| inventory report | `/buffer/` | 品目×拠点ごとの在庫の推移(入庫・出庫・在庫量) |
| resource report | `/resource/` | リソースごとの負荷率(能力に対する使用量) |
| problem report | `/problem/` | 計画上の問題(能力オーバー、部品不足など)の一覧 |
| constraint report | `/constraint/` | 受注が遅れた/不足した理由 |
| purchase order summary | `/purchase/` | 購買オーダーの期間別集計 |
| manufacturing order summary | `/operation/` | 製造オーダーの期間別集計 |

期間別のレポートは、画面上部で表示する期間の単位(日・週・月など)や範囲を変えられます。詳しくは 公式ドキュメント `user-interface/getting-around/selecting-time-buckets` を参照してください。

## 1. 需要レポート(demand report)

Sales メニューの **Demand report** を開きます。

![需要レポート（Demand report）](/images/frepple-tutorial-ja/demand-report.jpg)

期間ごとに、受注の数量(demand)と、計画で納品される数量(supply)が並びます。制約なし計画では、受注はすべて納期どおりに満たされるので、不足や遅れは出ないはずです(これは 06 章の制約あり計画で変わります)。

:::message
demo データには、状態が `open` の受注が 16 件あります(残りの約 200 件は `closed` の過去実績です)。実際に計画の対象になるのはこの 16 件です。Sales メニューの Sales orders(`/data/input/demand/`)で、status 列を見て確認しましょう。
:::

## 2. 在庫レポート(inventory report)

Inventory メニューの **Inventory report** を開きます。

![在庫レポート（Inventory report）](/images/frepple-tutorial-ja/inventory-report.jpg)

品目と拠点の組み合わせごとに、期首在庫・入庫(購買や製造による)・出庫(製造の消費や出荷)・期末在庫が期間別に出ます。「この部品はいつ入荷して、いつ使われるのか」を追うのに使います。

:::message
`screws` や `cushion` のような購買部品を選び、購買オーダー(入庫)が製造オーダー(出庫)よりも前に入っていることを確認してみましょう。
:::

## 3. リソースレポート(resource report)

Capacity メニューの **Resource report** を開きます。

![リソースレポート（Resource report）。Utilization % 列に負荷率が出る](/images/frepple-tutorial-ja/resource-report.jpg)

リソース(saw、grinder、assembly line など)ごとに、期間別の使用可能な能力(available)と負荷(load)、負荷率(utilization)が表示されます。

- 負荷率が **100% を超える** 期間は、能力オーバーです。
- 制約なし計画では、能力を超えて仕事を詰め込むため、100% を超える期間が出ることがあります。ただしデモデータは能力に余裕があり、制約なし計画でも 100% を超えません(ダッシュボードの負荷率は saw で 10% 前後でした)。100% を超える例は 07 章の自作モデルで体験します。
- 制約あり計画(06 章)では、100% を超えないように仕事が後ろにずらされます。

## 4. 問題レポート(problem report)

**Problem report**(`/problem/`)を開きます。Sales / Inventory / Capacity / Manufacturing の各メニューにも、それぞれの領域に絞った問題レポートがあります。

主な問題の種類は次のとおりです(公式ドキュメント `user-interface/plan-analysis/problem-report`)。

| 対象 | 問題 |
|---|---|
| Resource | overload(能力オーバー) |
| Buffer | material shortage(部品・在庫の不足)、invalid data(補充手段がない/多すぎる) |
| Operation | precedence(工程の前後関係が守られていない) |
| Demand | invalid data(計画できないデータ不備) |

制約なし計画では、「能力が足りない」「部品が足りない」といった問題が、ここに **警告として** 並びます。デモデータで制約なし計画を実行すると、`material shortage`(部品の不足)が 5 件出ます。計画自体は納期を満たしているので、その代わりに「現実にはこの前提が崩れる」ことを教えてくれるわけです。

## 5. 供給経路をたどる(Supply path / Where used)

品目・受注・リソースなどの画面には、その行のコンテキストメニューがあります (行の横のアイコンをクリックします)。そこから **supply path**(その品目がどこから供給されるか)や **where used**(その品目がどこで使われるか)を開けます。詳しくは 公式ドキュメント `user-interface/plan-analysis/supply-path-where-used` を参照してください。

例えば `chair` の supply path をたどると、次のような流れが見えるはずです。

- 組立(Assemble chair)で作る
- 部品の chair leg は Saw chair leg で作る
- さらにその材料の wooden beam は wood supplier から購入する

## つまずきポイント

- レポートが空になる: 表示期間が計画の範囲から外れている可能性があります。デモデータの計画基準日は「今日」です(04 章)。画面上部の期間が基準日を含んでいるか確認してください。
- 問題レポートに何も出ない: 制約なし計画でも、問題がない場合は空になります。「計画を実行したか」「データベースを切り替えていないか」を確認してください。
- 英語の用語が分かりにくい: `buffer` は「品目×拠点」の在庫の単位、`operation` は工程、`demand` は受注(または予測)のことです。
