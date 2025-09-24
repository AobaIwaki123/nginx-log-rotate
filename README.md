# nginxのログをcronでログローテーションする

nginx コンテナ内で cron job を使ってログローテーションを行い、ローテーションしたログをコンテナ外に出力するプロジェクトです。

## 機能

- **自動ログローテーション**: cronによる日次または任意の頻度でのログローテーション
- **ログ圧縮**: 古いログファイルの自動圧縮（gzip）
- **外部出力**: ローテーションしたログをホストに保存
- **nginx再読み込み**: ローテーション後の自動nginx設定再読み込み

## デバッグ

```sh
# ログローテーションを強制実行
docker compose run --rm -it nginx /usr/sbin/logrotate -f -s /var/lib/logrotate/status /etc/logrotate.d/nginx
```

## ディレクトリ構成

```
nginx-log-rotate/
├── compose.yml                    # Docker Compose設定
├── test-logrotate.sh              # テストスクリプト
├── README.md
└── nginx/
    ├── Dockerfile                 # nginxコンテナ設定
    ├── logs/                      # 現在のログファイル（マウント）
    ├── rotated-logs/              # ローテーション済みログ（マウント）
    └── cron/
        ├── start.sh               # コンテナ起動スクリプト
        ├── logrotate              # cron設定ファイル
        ├── logrotate.conf         # logrotate設定
        └── state                  # logrotate状態ファイル
```

## 設定のカスタマイズ

### ローテーション頻度の変更

`nginx/cron/logrotate` ファイルでcronの実行スケジュールを変更：

```bash
# 毎日午前2時に実行
0 2 * * * root /usr/sbin/logrotate -s /var/lib/logrotate/status /etc/logrotate.d/nginx > /var/log/logrotate.log 2>&1

# 毎時間実行
0 * * * * root /usr/sbin/logrotate -s /var/lib/logrotate/status /etc/logrotate.d/nginx > /var/log/logrotate.log 2>&1
```

### ログ保持期間の変更

`nginx/cron/logrotate.conf` の `rotate` 値を変更：

```bash
# 30世代保持
rotate 30

# 7世代保持
rotate 7
```
