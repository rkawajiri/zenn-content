---
title: "制約あり計画"
---

この章のゴール: 制約あり(有限能力)の計画を作り、制約なし計画との違いと、受注が遅れる理由・ボトルネックを読み取れるようになる。

:::message
**この章で学べる計画の考え方**

- 制約の種類（能力・製造リードタイム・調達リードタイム）と、それぞれが何を守るか
- 守れなかった分は「問題」ではなく「受注の遅れ」として現れる
- 遅れの理由をたどり、ボトルネックを特定する考え方
:::

## 制約あり計画とは

04 章の制約なし計画は、「すべての受注を納期どおりに」を最優先にして、能力オーバーや過去日付のオーダーを許しました。一方、**制約あり計画** は、守るべき制約を守り、その範囲でできるだけ納期に近づけます。守れない分は、受注を **遅らせる** か **一部を出荷しない(不足)** ことで表現します。

frePPLe で選べる制約は 3 つあります(公式ドキュメント `command-reference` の「Generate a plan」)。

| 制約 | 意味 |
|---|---|
| Capacity | リソースの能力を超えない |
| Manufacturing lead time | 製造・配送オーダーを、計画基準日より前(過去)に開始・終了しない |
| Purchasing lead time | 購買オーダーを、計画基準日より前(過去)に開始・終了しない |

:::message alert
「confirmed」のオーダーだけは、過去の日付でも許されます(すでに実行に移した、と見なされるためです)。`proposed` と `approved` のオーダーは、必ず未来になります。
:::

## 制約あり計画を実行する

Admin メニューの **Execute** を開き、「Create a plan(計画を作成)」のカードで次のように設定します。

1. 「Generate supply plan(サプライチェーンを生成)」にチェックを入れる。
2. Plan type は「**Constrained plan**」を選ぶ。
3. Constraints は 3 つとも **オン**(Capacity / Manufacturing lead time / Purchasing lead time)。
4. `Launch`(起動)を押す。

同じことを Web API でするなら、次のようになります(4 章の `plan.sh` を使います)。

```bash
./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply"
```

## 制約なし計画との比較

ここからが本題です。同じ受注データで、結果がどう変わるかを見比べます。以下は、手元で実行したときの結果です(`open` の受注 16 件、基準日は実行した日)。

| 見るところ | 制約なし計画 | 制約あり計画 |
|---|---|---|
| problem report | `material shortage` が 5 件 | 問題なし |
| constraint report | 空 | 29 行(下の表) |
| 納期に遅れる受注 | なし | 8 件(最大で約 2 か月遅れ) |

制約あり計画で問題がなくなったのは、制約を守れるように計画を組み直した結果です。守れなかった分は、問題としてではなく「受注の遅れ」として現れます。

## 遅れの理由を調べる(constraint report)

Sales メニューの **Constraint report**(`/constraint/`)を開きます。遅れた受注と、その理由が並びます(公式ドキュメント `user-interface/plan-analysis/constraint-report`)。

![制約レポート（Constraint report）。Demand ごとに、遅れの理由（Name）と対象（Owner）が並ぶ](/images/frepple-tutorial-ja/constraint-report.jpg)

デモデータの制約あり計画では、次の理由が出ました。

| 理由(name) | 行数 | 意味 |
|---|---|---|
| manufacturing lead time | 10 | 製造を始めるべき日がすでに過去だった(例: `Assemble chair`、`Varnish chair`) |
| distribution lead time | 8 | 拠点間の輸送を始めるべき日がすでに過去だった |
| purchasing lead time | 1 | 購買を発注すべき日がすでに過去だった |
| await supply | 5 | すでに確定している補充(confirmed / approved)の到着を待った |
| overload | 5 | リソースの能力が足りなかった(`saw`、`assembly line`) |

先頭の 3 つが「リードタイム制約」で、基準日の翌日が納期の受注(`Demand 07` 〜 `Demand 14`)は、部品の調達や製造に必要な日数を考えると、間に合わせるには過去に着手していなければならなかった、という意味です。たとえば `wooden beam` の調達リードタイムは 7 日です。

表示された理由から、「なぜこの受注は遅れたのか」を 1 件ずつ説明できるようになるのがゴールです。たとえば `Demand 08`(square table 30 個)には、`overload`(`saw` と `assembly line`)の行が付いています。

## ボトルネックを見つける

「遅れた受注が、どのリソースに引っかかっているか」を、次の手順で調べます。

1. constraint report で、`overload` の行を探す。
2. その行の owner 列(能力が足りなかったリソース)を見る。同じリソースに多くの受注が集中していれば、それがボトルネックです。デモデータでは `saw` と `assembly line` が出ました。
3. Capacity メニューの **Resource report** で、そのリソースの負荷率が高い期間を確認する。

ボトルネックの見つけ方は、公式のビデオ手順(公式ドキュメント `a-day-in-the-life/production-planning/identify-bottleneck-resources`)も参考になります。遅れた受注の確認は 公式ドキュメント `a-day-in-the-life/production-planning/review-late-orders` にあります。

## ためしに: 制約を 1 つずつ外してみる

制約の効果を実感するために、次の 3 パターンを実行して、遅れる受注の数を見比べてみてください。手元では次のようになりました。

| パターン | `constraint` | 結果 |
|---|---|---|
| A. 能力だけ | `capa` | 遅れる受注はなし。constraint report も空 |
| B. リードタイムだけ | `mfg_lt,po_lt` | 遅れる受注が 9 件。constraint report は 23 行 |
| C. 全部 | `capa,mfg_lt,po_lt` | 遅れる受注が 8 件。constraint report は 29 行 |

```bash
./plan.sh "plantype=1&constraint=capa&env=supply"
```

このデモデータでは、遅れの主な原因は **リードタイム** で、能力(`capa`)だけでは遅れが出ませんでした。能力の制約が効いてくるのは、07 章で自作するモデルのような、リソースに余裕がない場合です。

:::message
実行するたびに計画は上書きされます。結果を残しておきたいときは、Excel にエクスポートするか、10 章の What-if シナリオにコピーして比較します。
:::

## つまずきポイント

- 制約あり計画にしても遅れが出ない: 制約のチェックが外れていないか、Plan type が「Constrained plan」になっているかを確認してください。
- constraint report が空: 制約なし計画では空になります。制約あり計画を実行した後で見てください。
- 数字が本文と違う: 日付や frePPLe のバージョンで変わります。傾向(リードタイム制約が主因であること)を確認してください。
