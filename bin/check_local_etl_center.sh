#! /usr/bin/env bash
#set -e会在执行出错时结束程序,如果加上，则任务组里的错误重试没法启用
#set -e
#set -x会在执行每一行 shell 脚本时，把执行的内容输出来
#set -x

# shellcheck source=/dev/null
source ~/.bash_profile

BASE_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
CONFIG_DIR="${BASE_DIR}/config"
CONFIGFILE="${CONFIG_DIR}/local_logs.ini"
LOGS_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOGS_DIR}/start_servers.$(date '+%Y-%m-%d').log"

PRONAME="${0##*/}"
MSG_SUCCESS="serve_etl_client:true"
MSG_FAILURE="serve_etl_client:false"
MATCH_STR="EtlServiceHandle"
SECTION_NAME="etl-center"
ETL_CENTER_LOG="etl-center-info.log"

# 定义读取ini配置文件中section值的函数
get_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"

    # 读取section中key值
    awk -F '=' -v sec="$section" -v k="$key" '
        $0 ~ "\\[" sec "\\]" { flag=1; next }  # 匹配到目标 [section]，设置标志位为1，并跳过该行
        /^\[/ { flag=0 }           # 遇到下一个 section（以[开头），重置标志位为0
        flag && $1 == k {          # 如果标志位为1，且第一列等于目标key
            print $2               # 打印对应的值
            exit                   # 找到后立即退出，提高效率
        }
    ' "$file"
}

LOCAL_ADDR="$(ip addr | grep -v 127 | grep -Eo "inet[^0-9]+[.0-9]+"|grep -Eo "[.0-9]+"|head -1)"

echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:local address:${LOCAL_ADDR}" | tee -a ${LOG_FILE}

servers=$(get_ini_value "${CONFIGFILE}" "ADDRESS" "$LOCAL_ADDR")
echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:local servers:${servers}" | tee -a ${LOG_FILE}

arr=($(echo $servers | sed 's/,/ /g'))
for index in "${!arr[@]}";
  do
	section=${arr[$index]}

    if [[ "$section" != "${SECTION_NAME}" ]]; then
        continue
    fi

    log_path=$(get_ini_value "${CONFIGFILE}" "${section}" "log_path")

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:log_path=${log_path}" | tee -a ${LOG_FILE}

	if [[ -z "$log_path" ]] ; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} WARN:${section} ${log_path} 为空" | tee -a ${LOG_FILE}
        continue
    fi

    etl_center_log="${ETL_CENTER_LOG}"
    if [[ ! -f "${log_path}/${etl_center_log}" ]] ; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} ERROR:日志文件不存在 ${log_path}/${etl_center_log}" | tee -a ${LOG_FILE}
        continue
    fi

    cd "${log_path}" || break
    # 1. 提取最后一行
    last_line=$(grep "$(date '+%Y-%m-%d').*${MATCH_STR}" "${etl_center_log}" | tail -n 1)
    if [ -z "$last_line" ]; then
        break
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:last_line=${last_line}" | tee -a ${LOG_FILE}
    # 2. 判断最后这一行是否包含 ERROR
    if echo "$last_line" | grep -q "ERROR"; then
        break
    else
        echo "${MSG_SUCCESS}"
        exit 0
    fi

done

echo "${MSG_FAILURE}" | tee -a ${LOG_FILE}
