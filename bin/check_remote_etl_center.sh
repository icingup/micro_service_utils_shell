#! /usr/bin/env bash
#set -e会在执行出错时结束程序,如果加上，则任务组里的错误重试没法启用
#set -e
#set -x会在执行每一行 shell 脚本时，把执行的内容输出来
#set -x

# shellcheck source=/dev/null
source ~/.bash_profile

BASE_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
CONFIG_DIR="${BASE_DIR}/config"
CONFIGFILE="${CONFIG_DIR}/remote_server.ini"
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
for index in "${!arr[@]}";
  do
	section=${arr[$index]}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${LOCAL_ADDR} 第${index}个服务 ${section}" | tee -a ${LOG_FILE}

    remote_address=$(get_ini_value "${CONFIGFILE}" "${section}" "remote_address")
    remote_check_shell=$(get_ini_value "${CONFIGFILE}" "${section}" "remote_check_shell")
    remote_user=$(get_ini_value "${CONFIGFILE}" "${section}" "remote_user")
	#remote_password=$(get_ini_value "${CONFIGFILE}" "${section}" "remote_password")
    remote_success_msg=$(get_ini_value "${CONFIGFILE}" "${section}" "remote_success_msg")
	remote_fix_shell=$(get_ini_value "${CONFIGFILE}" "${section}" "remote_fix_shell")

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:remote_address=${remote_address}" | tee -a ${LOG_FILE}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:remote_check_shell=${remote_check_shell}" | tee -a ${LOG_FILE}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:remote_user=${remote_user}" | tee -a ${LOG_FILE}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:remote_success_msg=${remote_success_msg}" | tee -a ${LOG_FILE}
	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:remote_fix_shell=${remote_fix_shell}" | tee -a ${LOG_FILE}


	if [[ -z "$remote_address" ]] || [[ -z "$remote_check_shell" ]] || [[ -z "$remote_user" ]] || [[ -z "$remote_success_msg" ]] || [[ -z "$remote_fix_shell" ]] ; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} WARN:${section}配置错误，缺少必要参数" | tee -a ${LOG_FILE}
        continue
    fi

	count=0
	address_arr=($(echo $remote_address | sed 's/,/ /g'))
	for j in "${!address_arr[@]}";
	do
		addr=${address_arr[$j]}
		#output=$(sshpass -p "${remote_password}" ssh "${remote_user}"@"${addr}" "${remote_check_shell}")
        output=$(ssh "${remote_user}"@"${addr}" "${remote_check_shell}")
		echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:output - ${output}" | tee -a "${LOG_FILE}"
		# 静默匹配，匹配到返回0，没匹配到返回1
		if echo "${output}" | grep -q "${remote_success_msg}"; then
			count=$((count + 1))
		fi

		# 如果count大于1,则调用remote_fix_shell进行修复
		if [[ $count -gt 1 ]] ; then
			echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:存在多个服务，需要在 ${addr} 远程调用 ${remote_fix_shell} 进行修复" | tee -a "${LOG_FILE}"			

			#result=$(sshpass -p "gyyh@123" ssh "${remote_user}@${addr}" bash << EOF 	2>&1
			result=$(ssh "${remote_user}@${addr}" bash << EOF 	2>&1
${remote_fix_shell}
EOF
)

			echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:result - ${result}" | tee -a "${LOG_FILE}"

			count=1

		fi

  done
done
