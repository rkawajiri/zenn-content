---
title: "環境構築とログイン"
---

この章のゴール: Docker Compose で frePPLe を起動し、ブラウザでログインして画面の全体像をつかむ。

:::message
**この章で学べる計画の考え方**

- 計画システムの入力（受注・在庫・購買・製造・リソース）と、出力（購買・製造・配送のオーダー）
- 3 章で見た画面は、データを入れて計画エンジンを動かした結果である（次の章から、自分で作る）
:::

## 起動する

次の内容の `docker-compose.yml` を使います。これは 公式ドキュメント `installation-guide/advanced/docker-compose` のサンプルを、最小限に絞ったものです。同じものを、この本のリポジトリの `examples/docker/docker-compose.yml` に置いています。`git clone` したあと、`examples/docker` に移動して、次の「起動します」のコマンドを実行できます。自分でフォルダを作る場合は、下の内容を `docker-compose.yml` として保存してください。

```yaml
services:
  frepple:
    image: "ghcr.io/frepple/frepple-community:9.17.0"
    container_name: frepple-community-webserver
    ports:
      - 9000:80
    depends_on:
      - frepple-community-postgres
    networks:
      - backend
    environment:
      POSTGRES_HOST: "frepple-community-postgres"
      POSTGRES_PORT: 5432
      POSTGRES_USER: "frepple"
      POSTGRES_PASSWORD: "frepple"
      FREPPLE_TIME_ZONE: "Asia/Tokyo"

  frepple-community-postgres:
    image: "postgres:16"
    container_name: frepple-community-postgres
    networks:
      - backend
    environment:
      POSTGRES_PASSWORD: frepple
      POSTGRES_DB: frepple
      POSTGRES_USER: frepple
      POSTGRES_DBNAME: frepple

networks:
  backend:
```

公式のサンプルから、次の 2 か所を変えています。

| 設定 | 理由 |
|---|---|
| `image: ...frepple-community:9.17.0` | 版を **9.17.0 に固定** するため(公式サンプルは `latest`)。理由は下の「版について」を参照 |
| `FREPPLE_TIME_ZONE: "Asia/Tokyo"` | 日本時間で表示するため(公式サンプルは `UTC`) |

## 版について: 9.17.0 を使う理由

この本は、frePPLe Community Edition の **9.17.0**（2026-07-10 リリース）で動作を確認しています。`latest` ではなく版を固定するのは、次の理由からです。

- 9.18.1 では、REST API で **製造オーダーの日時を更新できません**（HTTP 500）。14 章では REST API で計画結果を書き戻すので、この不具合のない 9.17.0 を使います。

原因や確認した内容は、14 章のコラムに書きました。新しい版で試すときは、14 章の書き戻しが動くかを先に確認してください。

起動します。

```bash
cd examples/docker    # 自分でフォルダを作った場合は、そのフォルダへ移動
docker compose up -d
docker compose logs -f frepple    # 起動ログを確認(Ctrl+C で抜ける)
```

初回はデータベースの初期化に少し時間がかかります(手元の環境では 20 秒ほどで応答しました)。ブラウザで http://localhost:9000/ を開いてください。

:::message
イメージの取得(pull)で認証エラーになる場合は、GitHub のアカウントで `docker login ghcr.io` を実行してから、もう一度試してください。詳しくは 公式ドキュメント `installation-guide/docker-container` を参照してください。
:::

## ログインする

ユーザー名 `admin`、パスワード `admin` でログインします。

初期パスワードのままだと警告が表示されます。学習用のローカル環境ならそのままでも構いませんが、手順を確認しておきましょう。パスワードは次のコマンドで変更できます。

```bash
docker exec -it frepple-community-webserver frepplectl changepassword admin
```

## 画面の言語

ブラウザの言語が日本語だと、一部のメニューやボタンが日本語で表示されます。ただし、翻訳されていない項目は英語のままです。この手順書では英語の表記で書き、日本語の訳が確認できたものだけ括弧内に添えます。見つからないときは、URL でも開けます。

## 画面の歩き方

ログインすると、上部にメニューが並びます。主なものは次のとおりです。メニューの構成は `freppledb/*/menu.py` で定義されています。

| メニュー | 主な内容 |
|---|---|
| sales | 受注(demand)、品目、ロケーション、顧客、需要レポート |
| inventory | 在庫レポート、バッファ、拠点間の輸送(配送オーダー) |
| purchasing | 購買オーダー、サプライヤー、品目×サプライヤー |
| capacity | リソース、リソースレポート、問題レポート(能力) |
| manufacturing | 製造オーダー、工程(operation)、カレンダー |
| admin | **execute**(計画の生成、データのロードなど) |

:::message alert
メニューの項目は、データの有無で変わります。たとえば受注(sales orders)の画面は、品目・ロケーション・顧客がそれぞれ1件以上ないと表示されません。空のデータベースで「メニューがない」と迷ったら、この点を疑ってください。詳しくは 公式ドキュメント `user-interface/getting-around/navigation` を参照してください。
:::

## 停止と再起動

```bash
docker compose stop          # 停止(データは残る)
docker compose start         # 再開
docker compose down          # コンテナを削除(このサンプルではデータベースの内容も消える)
```

## つまずきポイント

- `localhost:9000` につながらない: 起動直後は初期化中です。`docker compose logs frepple` を確認してください。
- ポート 9000 が使用中: `ports` の左側(`9000:80` の 9000)を別の番号に変えてください。
- `docker compose down` の後にデータが消える: このサンプルはデータベースのボリュームを永続化していません。学習を中断して続きをやりたいときは `down` ではなく `stop` を使うか、postgres にボリュームを追加してください。
