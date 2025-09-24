#!/bin/bash

# nginx-log-rotate テストスクリプト
# このスクリプトはnginxのログローテーション機能をテストします

set -e

# 色付きの出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ヘルプ表示
show_help() {
    echo "nginx-log-rotate テストスクリプト"
    echo ""
    echo "使用方法:"
    echo "  ./test-logrotate.sh [オプション]"
    echo ""
    echo "オプション:"
    echo "  -h, --help     このヘルプを表示"
    echo "  -s, --setup    テスト環境をセットアップ"
    echo "  -t, --test     ログローテーションテストを実行"
    echo "  -c, --clean    テスト環境をクリーンアップ"
    echo "  -a, --all      セットアップ→テスト→クリーンアップを順次実行"
    echo "  -v, --verbose  詳細な出力を表示"
    echo ""
}

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Docker Composeが実行中かチェック
check_docker_compose() {
    log_info "Docker Composeサービスの状態を確認中..."
    if ! docker compose ps | grep -q "nginx.*running"; then
        log_warning "nginxコンテナが起動していません。起動します..."
        docker compose up -d
        sleep 5
    fi
    log_success "nginxコンテナが起動中です"
}

# テスト環境をセットアップ
setup_test_env() {
    log_info "=== テスト環境セットアップ開始 ==="
    
    # Docker Composeを起動
    check_docker_compose
    
    # rotated-logsディレクトリを確保
    mkdir -p nginx/rotated-logs
    
    # cronサービスの状態確認
    log_info "cronサービスの状態を確認中..."
    docker compose exec nginx bash -c "service cron status" || {
        log_warning "cronサービスを起動中..."
        docker compose exec nginx bash -c "service cron start"
    }
    
    # logrotate設定の構文チェック
    log_info "logrotate設定の構文をチェック中..."
    docker compose exec nginx bash -c "/usr/sbin/logrotate -d /etc/logrotate.d/nginx" > /dev/null 2>&1 && {
        log_success "logrotate設定は正常です"
    } || {
        log_error "logrotate設定にエラーがあります"
        exit 1
    }
    
    log_success "=== テスト環境セットアップ完了 ==="
}

# ログファイルの状態を表示
show_log_status() {
    log_info "現在のログファイル状態:"
    echo "--- コンテナ内 (/var/log/nginx/) ---"
    docker compose exec nginx bash -c "ls -lh /var/log/nginx/ 2>/dev/null || echo 'ディレクトリが存在しません'"
    echo ""
    echo "--- ホスト側 (./nginx/logs/) ---"
    ls -lh nginx/logs/ 2>/dev/null || echo "ディレクトリが存在しません"
    echo ""
    echo "--- ローテーション済みログ (./nginx/rotated-logs/) ---"
    ls -lh nginx/rotated-logs/ 2>/dev/null || echo "ファイルが存在しません"
    echo ""
}

# アクセスログを生成
generate_test_logs() {
    log_info "テスト用のアクセスログを生成中..."
    
    for i in {1..10}; do
        docker compose exec nginx bash -c "curl -s localhost:80 >/dev/null"
        if [ "$VERBOSE" = true ]; then
            echo "  リクエスト $i/10 完了"
        fi
    done
    
    # 手動でログエントリを追加
    docker compose exec nginx bash -c "echo 'Test log entry $(date)' >> /var/log/nginx/access.log"
    docker compose exec nginx bash -c "echo 'Test error entry $(date)' >> /var/log/nginx/error.log"
    
    log_success "テストログの生成完了"
}

# ログローテーションテストを実行
run_logrotate_test() {
    log_info "=== ログローテーションテスト開始 ==="
    
    # 現在の状態を表示
    show_log_status
    
    # テストログを生成
    generate_test_logs
    
    log_info "ログローテーションを強制実行中..."
    
    # 最初のローテーション
    docker compose exec nginx bash -c "/usr/sbin/logrotate -f /etc/logrotate.d/nginx" && {
        log_success "1回目のローテーション完了"
    } || {
        log_warning "1回目のローテーションでエラーが発生（既存ファイルが原因の可能性）"
    }
    
    # 少し待機
    sleep 2
    
    # ローテーション後の状態確認
    log_info "ローテーション後の状態:"
    show_log_status
    
    # さらにログを生成
    log_info "追加のテストログを生成中..."
    generate_test_logs
    
    # logrotateの状態ファイルを確認
    log_info "logrotateの状態ファイルを更新して2回目のローテーションを実行..."
    docker compose exec nginx bash -c "rm -f /var/lib/logrotate/status"
    
    # 2回目のローテーション（圧縮テスト用）
    docker compose exec nginx bash -c "/usr/sbin/logrotate -f /etc/logrotate.d/nginx" && {
        log_success "2回目のローテーション完了"
    } || {
        log_warning "2回目のローテーションでエラーが発生"
    }
    
    # 最終的な状態確認
    log_info "最終的なログファイル状態:"
    show_log_status
    
    # 圧縮ファイルの確認
    log_info "圧縮ファイルの内容確認:"
    docker compose exec nginx bash -c "ls -la /var/log/nginx/*.gz 2>/dev/null" && {
        log_info "圧縮ファイルの中身をサンプル表示:"
        docker compose exec nginx bash -c "zcat /var/log/nginx/*.gz 2>/dev/null | head -3"
        log_success "圧縮機能は正常に動作しています"
    } || {
        log_warning "圧縮ファイルが見つかりませんでした"
    }
    
    # cronのログも確認
    log_info "cronの実行ログを確認:"
    docker compose exec nginx bash -c "cat /var/log/logrotate.log 2>/dev/null || echo 'ログファイルが存在しません'"
    
    log_success "=== ログローテーションテスト完了 ==="
}

# テスト環境をクリーンアップ
cleanup_test_env() {
    log_info "=== テスト環境クリーンアップ開始 ==="
    
    # ローテーションされたファイルを削除
    log_info "ローテーションファイルを削除中..."
    docker compose exec nginx bash -c "rm -f /var/log/nginx/*.gz /var/log/nginx/*-[0-9]* 2>/dev/null || true"
    
    # ホスト側のローテーションファイルも削除
    rm -f nginx/logs/*.gz nginx/logs/*-[0-9]* 2>/dev/null || true
    rm -rf nginx/rotated-logs/* 2>/dev/null || true
    
    # logrotateの状態ファイルをリセット
    docker compose exec nginx bash -c "rm -f /var/lib/logrotate/status /var/log/logrotate.log 2>/dev/null || true"
    
    # 現在のログファイルを初期化
    docker compose exec nginx bash -c "echo '' > /var/log/nginx/access.log && echo '' > /var/log/nginx/error.log"
    
    log_success "=== テスト環境クリーンアップ完了 ==="
}

# オプション解析
VERBOSE=false
ACTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--setup)
            ACTION="setup"
            shift
            ;;
        -t|--test)
            ACTION="test"
            shift
            ;;
        -c|--clean)
            ACTION="clean"
            shift
            ;;
        -a|--all)
            ACTION="all"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# アクションが指定されていない場合はヘルプを表示
if [ -z "$ACTION" ]; then
    show_help
    exit 0
fi

# メインの実行部分
case $ACTION in
    "setup")
        setup_test_env
        ;;
    "test")
        run_logrotate_test
        ;;
    "clean")
        cleanup_test_env
        ;;
    "all")
        setup_test_env
        echo ""
        run_logrotate_test
        echo ""
        read -p "クリーンアップを実行しますか？ (y/N): " confirm
        if [[ $confirm == [yY] ]]; then
            cleanup_test_env
        else
            log_info "クリーンアップをスキップしました"
        fi
        ;;
esac

log_success "スクリプト実行完了"
