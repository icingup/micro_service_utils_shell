#! /usr/bin/env bash
set -e
set -x

# 脚本名：trim_script.sh
# 功能：将shell脚本中的windows分隔符转为Unix分隔符。从git上面拉起的代码在部署前需要先执行

BASE_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"


find "${BASE_DIR}"   -type f  \( -name "*.sh" -o -name "*.ini" \) |while read -r line; do

    echo "line = $line"
    echo "trim $line"
    tr -d '\r' < "${line}" > "${line}.tmp"
    cat "${line}.tmp" > "${line}"
    rm -f "${line}.tmp"

done
