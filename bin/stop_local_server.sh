#! /usr/bin/env bash
#set -e会在执行出错时结束程序,如果加上，则任务组里的错误重试没法启用
#set -e
#set -x会在执行每一行 shell 脚本时，把执行的内容输出来
#set -x

# shellcheck source=/dev/null
source ~/.bash_profile

BASE_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
CONFIG_DIR="${BASE_DIR}/config"
CONFIGFILE="${CONFIG_DIR}/local_server.ini"
LOGS_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOGS_DIR}/start_servers.$(date '+%Y-%m-%d').log"

PRONAME="${0##*/}"

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
for index in $(seq $((${#arr[@]}-1)) -1 0);
  do
	section=${arr[$index]}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${LOCAL_ADDR} 第${index}个服务 ${section}" | tee -a ${LOG_FILE}

    dir=$(get_ini_value "${CONFIGFILE}" "${section}" "dir")
    stop=$(get_ini_value "${CONFIGFILE}" "${section}" "stop")
    port=$(get_ini_value "${CONFIGFILE}" "${section}" "port")

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:dir=${dir}" | tee -a ${LOG_FILE}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:stop=${stop}" | tee -a ${LOG_FILE}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:port=${port}" | tee -a ${LOG_FILE}

	if [[ -z "$port" ]] || [[ -z "$stop" ]] || [[ -z "$dir" ]] || [[ ! -d "${dir}" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} WARN:${section}配置错误，缺少必要参数" | tee -a ${LOG_FILE}
        continue
    fi

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:检查${section}启动情况" | tee -a ${LOG_FILE}
	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:ss -ntlp | grep "${port}" | awk '{print \$6}' | awk -F ',' '{print \$2}' | awk -F '=' '{print \$2}' | head -1" | tee -a ${LOG_FILE}

	pid="$(ss -ntlp | grep "${port}" | awk '{print $6}' | awk -F ',' '{print $2}' | awk -F '=' '{print $2}' | head -1)"

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:pid=${pid}" | tee -a ${LOG_FILE}

	if [[ -z $pid ]] ; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${section} 端口 ${port} 未启用" | tee -a ${LOG_FILE}
		continue
	fi

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${section} 准备停止服务" | tee -a ${LOG_FILE}
	cd "${dir}" || exit
    ${stop}


done
