#! /usr/bin/env bash
#set -e会在执行出错时结束程序,如果加上，则任务组里的错误重试没法启用
#set -e
#set -x会在执行每一行 shell 脚本时，把执行的内容输出来
#set -x

# shellcheck source=/dev/null
source ~/.bash_profile

BASE_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
SHELL_DIR="${BASE_DIR}/bin"
CONFIG_DIR="${BASE_DIR}/config"
CONFIGFILE="${CONFIG_DIR}/local_logs.ini"
LOGS_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOGS_DIR}/backup_log.$(date '+%Y-%m-%d').log"

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

# 备份日期参数，默认为头一天
data_time=$1
if [ "${#data_time}" -ne 8 ]; then
    data_time=$(date -d "-1 day" +%Y%m%d)
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:it use yesterday($data_time) as condition date"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:it use parameter($1) as condition date"
fi

local_addr="$(ip addr | grep -v 127 | grep -Eo "inet[^0-9]+[.0-9]+"|grep -Eo "[.0-9]+"|head -1)"

echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:local address:${local_addr}" | tee -a ${LOG_FILE}

servers=$(get_ini_value "${CONFIGFILE}" "ADDRESS" "$local_addr")
echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:local servers:${servers}" | tee -a ${LOG_FILE}

remote_ip=$(get_ini_value "${CONFIGFILE}" "REMOTE" "remote_ip")
remote_port=$(get_ini_value "${CONFIGFILE}" "REMOTE" "remote_port")
remote_user=$(get_ini_value "${CONFIGFILE}" "REMOTE" "remote_user")
remote_passwd=$(get_ini_value "${CONFIGFILE}" "REMOTE" "remote_passwd")
remote_path=$(get_ini_value "${CONFIGFILE}" "REMOTE" "remote_path")

echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} DEBUG:remote_ip:${remote_ip}"
echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} DEBUG:remote_port:${remote_port}"
echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} DEBUG:remote_user:${remote_user}"
#echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} DEBUG:remote_passwd:${remote_passwd}"
echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} DEBUG:remote_path:${remote_path}"

if [ -z "$remote_ip" ] ||[ -z "$remote_port" ] || [ -z "$remote_user" ] || [ -z "$remote_passwd" ] || [ -z "$remote_path" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} ERROR:远程参数不全，退出备份程序"
    exit 2
fi

arr=($(echo $servers | sed 's/,/ /g'))
for index in "${!arr[@]}";
  do

    section=${arr[$index]}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${local_addr} 第${index}个服务 ${section}" | tee -a ${LOG_FILE}

    log_path=$(get_ini_value "${CONFIGFILE}" "${section}" "log_path")
	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:log_path=${log_path}" | tee -a ${LOG_FILE}

	if [[ -z "${log_path}" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} WARN:服务 ${section} 对应的日志文件目录 $log_path 不存在，跳过本次备份操作" | tee -a ${LOG_FILE}
        continue
    elif [[ ! -d "${log_path}" ]] ; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} WARN:服务 ${section} 对应的日志文件目录 $log_path 不存在，跳过本次备份操作" | tee -a ${LOG_FILE}
        continue
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:备份目录$log_path下日志文件" | tee -a ${LOG_FILE}

    cd "$log_path"|| exit

	#打包文件名
	tar_name="${section}"."${data_time}".tar
	#压缩文件名
	compress_name="${tar_name}".gz
	# 正则转义 . 为 \.
	esc1=$(sed 's/\./\\./g' <<< "$tar_name")
	esc2=$(sed 's/\./\\./g' <<< "$compress_name")
	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:esc1=${esc1},=${esc2}" | tee -a ${LOG_FILE}

	# 备份包含 "YYYY-MM-DD" 文件/文件夹
	log_time_format="$(date -d "${data_time}" '+%Y-%m-%d')"

	if compgen -G "*${log_time_format}*" | grep -vE "^(${esc1}|${esc2})$" > /dev/null; then
	    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:执行日志备份:tar -cvf ${tar_name} --exclude="${tar_name}" --exclude="${compress_name}" *${log_time_format}*" | tee -a ${LOG_FILE}

        tar -cvf "${tar_name}" --exclude="${tar_name}" --exclude="${compress_name}".tar *"${log_time_format}"* 2>&1 | tee -a ${LOG_FILE}

    fi

	# 备份包含 "YYYYMMDD" 文件/文件夹
	log_time_format="$(date -d "${data_time}" '+%Y%m%d')"

	if compgen -G "*${log_time_format}*" | grep -vE "^(${esc1}|${esc2})$" > /dev/null; then
		if [ -f "${tar_name}" ]; then
			# 如果存在，则追加 (-r)
			echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:执行日志备份:tar -rvf ${tar_name} --exclude="${tar_name}" --exclude="${compress_name}" *${log_time_format}*" | tee -a ${LOG_FILE}

			tar -rvf "${tar_name}" --exclude="${tar_name}" --exclude="${compress_name}".tar *"${log_time_format}"* 2>&1 | tee -a ${LOG_FILE}
		else
			# 如果不存在，则新建 (-c)
			echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:执行日志备份:tar -cvf ${tar_name} --exclude="${tar_name}" --exclude="${compress_name}" *${log_time_format}*" | tee -a ${LOG_FILE}

			tar -cvf "${tar_name}" --exclude="${tar_name}" --exclude="${compress_name}".tar *"${log_time_format}"* 2>&1 | tee -a ${LOG_FILE}

		fi

    fi

	if [ -f "${tar_name}" ]; then
		# 如果文件存在，则先压缩后上传

		gzip -f "${tar_name}" 2>&1 | tee -a ${LOG_FILE}

		echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:压缩包 ${compress_name} 文件内容: " | tee -a ${LOG_FILE}
		tar -tzvf ${compress_name} 2>&1 | tee -a ${LOG_FILE}


		result=$(timeout 5m sshpass -p "${remote_passwd}" sftp "${remote_user}"@"${remote_ip}" << EOF 	2>&1
cd ${remote_path}
mkdir ${data_time}
cd ${remote_path}/${data_time}
mkdir ${local_addr}
cd ${remote_path}/${data_time}/${local_addr}
lcd ${log_path}
-put ${compress_name}
EOF
)

		mark="$?"
		if [ $mark -ne 0 ]; then
			echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} ERROR:${log_file}日志上传失败"
		fi

		echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:result - ${result}" | tee -a "${LOG_FILE}"


		rm -f "${compress_name}"

	fi


	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:$(pwd)目录下清除过期(180天以前)数据日志，清除命令：find "${log_path}" -type f -mtime +180 -exec rm {} \\;" | tee -a ${LOG_FILE}
    find "${log_path}" -type f -mtime +180 -exec rm {} \;

done
