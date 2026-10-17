# examples

「生産計画を手を動かして学ぶ ― OSS の frePPLe で MRP・需要予測・CP-SAT まで」で使うスクリプトです。動作確認は frePPLe Community Edition 9.17.0 で行っています。

| 場所 | 内容 | 使う章 |
|---|---|---|
| `docker/docker-compose.yml` | frePPLe Community Edition 9.17.0 と PostgreSQL を起動する | 4 章 |
| `frepple-api/plan.sh` | Web API で計画を実行し、終わるまで待つ | 6 章〜 |
| `frepple-api/setup-model.sh` | 5 章の最小モデルを REST API でまとめて登録する | 5 章 |
| `frepple-api/reset-model.sh` | データを空にして、5 章の最小モデルを登録し直す（画面の「Clear all data」+ `setup-model.sh`） | 9・10・11・14 章 |
| `frepple-api/setup-distribution.sh` | 5 章のモデルに、倉庫と工場から倉庫への輸送、倉庫向けの受注を足す。先に `setup-model.sh` を実行しておく | 10 章 |
| `frepple-api/common.sh` | 上のスクリプトが共通で読み込む設定と関数（直接は実行しない） | ― |
| `cpsat/optimize.py` | OR-Tools CP-SAT でスケジュールを最適化し、REST API で書き戻す | 14 章 |
