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
for index in "${!arr[@]}";
  do
	section=${arr[$index]}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${LOCAL_ADDR} 第${index}个服务 ${section}" | tee -a ${LOG_FILE}

    dir=$(get_ini_value "${CONFIGFILE}" "${section}" "dir")
    start=$(get_ini_value "${CONFIGFILE}" "${section}" "start")
    stop=$(get_ini_value "${CONFIGFILE}" "${section}" "stop")
    port=$(get_ini_value "${CONFIGFILE}" "${section}" "port")
	before_start_check_net=$(get_ini_value "${CONFIGFILE}" "${section}" "before_start_check_net")
	before_start_check_http=$(get_ini_value "${CONFIGFILE}" "${section}" "before_start_check_http")

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:dir=${dir}" | tee -a ${LOG_FILE}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:start=${start}" | tee -a ${LOG_FILE}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:stop=${stop}" | tee -a ${LOG_FILE}
    echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:port=${port}" | tee -a ${LOG_FILE}
	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:before_start_check_net=${before_start_check_net}" | tee -a ${LOG_FILE}
	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:before_start_check_http=${before_start_check_http}" | tee -a ${LOG_FILE}

	if [[ -z "$port" ]] || [[ -z "$start" ]] || [[ -z "$dir" ]] || [[ ! -d "${dir}" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} WARN:${section}配置错误，缺少必要参数" | tee -a ${LOG_FILE}
        continue
    fi

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:检查${section}启动情况" | tee -a ${LOG_FILE}
	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:ss -ntlp | grep "${port}" | awk '{print \$6}' | awk -F ',' '{print \$2}' | awk -F '=' '{print \$2}' | head -1" | tee -a ${LOG_FILE}

	pid="$(ss -ntlp | grep "${port}" | awk '{print $6}' | awk -F ',' '{print $2}' | awk -F '=' '{print $2}' | head -1)"

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:pid=${pid}" | tee -a ${LOG_FILE}

	if [[ -n $pid ]] ; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${section} 测试端口 ${port} 运行情况,测试命令 timeout 1m nc -z ${LOCAL_ADDR} ${port}" | tee -a ${LOG_FILE}

		timeout 1m nc -z ${LOCAL_ADDR} ${port}
	    # shellcheck disable=SC2181
		if [ $? -eq 0 ]; then
			echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${section} 已在运行中，端口号为 ${port}" | tee -a ${LOG_FILE}
		else
			echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} ERROR:${section} 端口 ${port} 无响应，pid:${pid}" | tee -a ${LOG_FILE}

			#kill -9 "${pid}"
			#cd "${dir}" || exit
			#${start}

		fi

		continue

	fi

	if [[ -n $before_start_check_net ]] ; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${section} 检测前置 ${before_start_check_net} 是否就绪" | tee -a ${LOG_FILE}

        pre_service_arr=($(echo $before_start_check_net | sed 's/,/ /g'))
        for i in "${!pre_service_arr[@]}";
          do
              pre_service=${pre_service_arr[$i]}
              if [[ -n $pre_service ]] ; then
				 test_service="$(echo $pre_service | sed 's/:/ /g')"
                  until nc -z $test_service ;
                    do
	                echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME}-${LINENO} INFO:it waiting for [$pre_service]..." | tee -a ${LOG_FILE}
					
				    sleep 5
					
					done
					
					echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME}-${LINENO} INFO:成功！检测到 [$pre_service] 已就绪，已退出循环。" | tee -a ${LOG_FILE}
               fi
	    done

	fi

	if [[ -n $before_start_check_http ]] ; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${section} 检测前置 ${before_start_check_http} 是否就绪" | tee -a ${LOG_FILE}


        pre_service_arr=($(echo $before_start_check_http | sed 's/,/ /g'))
        for i in "${!pre_service_arr[@]}";
          do
              pre_service=${pre_service_arr[$i]}
              if [[ -n $pre_service ]] ; then
                  # 循环：直到拿到的状态码等于 200 才停止
                  until [ "$(curl -s -o /dev/null -w "%{http_code}" "$pre_service")" -eq 200 ]
                    do
						echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME}-${LINENO} INFO:当前返回码不是 200，等待 5 秒后重试..." | tee -a ${LOG_FILE}
				        sleep 5
					done

					echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME}-${LINENO} INFO:成功！$pre_service 检测到 HTTP 200，已退出循环。" | tee -a ${LOG_FILE}

               fi
	    done
    fi

	echo "$(date '+%Y-%m-%d %H:%M:%S') $$ ${PRONAME} - ${LINENO} INFO:${section} 所有前置均通过检测，准备启动服务" | tee -a ${LOG_FILE}

	cd "${dir}" || exit 0    
    ${start}

done
