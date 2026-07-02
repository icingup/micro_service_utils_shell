#! /usr/bin/env bash
#set -e会在执行出错时结束程序,如果加上，则任务组里的错误重试没法启用
#set -e
#set -x会在执行每一行 shell 脚本时，把执行的内容输出来
#set -x

# shellcheck source=/dev/null
source ~/.bash_profile

BASE_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"

${BASE_DIR}/bin/backup_local_logs.sh
