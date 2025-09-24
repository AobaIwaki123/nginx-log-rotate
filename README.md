# nginxのログをcronでログローテーションする

nginx コンテナ内で cron job を使ってログローテーションを行い、ローテーションしたログをコンテナ外に出力するプロジェクトです。

## 機能

- **自動ログローテーション**: cronによる日次または任意の頻度でのログローテーション
- **ログ圧縮**: 古いログファイルの自動圧縮（gzip）
- **外部出力**: ローテーションしたログをホストに保存
- **nginx再読み込み**: ローテーション後の自動nginx設定再読み込み

## クイックスタート

```bash
# 1. コンテナを起動
docker compose up -d

# 2. 動作確認
curl localhost:800
```

## テスト

簡単にログローテーション機能をテストできるスクリプトを提供しています：

```bash
# 実行権限を付与（初回のみ）
chmod +x test-logrotate.sh

# ヘルプを表示
./test-logrotate.sh --help

# 完全なテストを実行（推奨）
./test-logrotate.sh --all

# 個別にテスト実行
./test-logrotate.sh --setup   # テスト環境セットアップ
./test-logrotate.sh --test    # ログローテーションテスト
./test-logrotate.sh --clean   # テスト環境クリーンアップ
```

### テストスクリプトの機能

- **セットアップ**: Docker Composeサービス起動、cron起動確認、設定検証
- **テスト実行**: 
  - テスト用ログ生成（10回のHTTPリクエスト + 手動ログエントリ）
  - ログローテーション実行
  - 圧縮機能の確認
  - 結果の検証
- **クリーンアップ**: ローテーションファイル削除、ログリセット

## 手動でのテスト・確認

```bash
# コンテナに入る
docker compose exec nginx bash

# ログローテーションを手動実行
/usr/sbin/logrotate -f /etc/logrotate.d/nginx

# ログファイルの確認
ls -la /var/log/nginx/

# 圧縮ファイルの内容確認
zcat /var/log/nginx/*.gz

# cronサービスの状態確認
service cron status

# cronのログ確認
cat /var/log/logrotate.log
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
