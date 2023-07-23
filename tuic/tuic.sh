#!/bin/bash
tuV="23.7.23 V 2.1"
remoteV=`wget -qO- https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/tuic/tuic.sh | sed  -n 2p | cut -d '"' -f 2`
chmod +x /root/tuic.sh
ln -sf /root/tuic.sh /usr/bin/tu
red='\033[0;31m'
yellow='\033[0;33m'
bblue='\033[0;34m'
plain='\033[0m'
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
yellow " 请稍等3秒……正在扫描vps类型及参数中……"
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
sys(){
[ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
[ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
[ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return;}
op=`sys`
version=`uname -r | awk -F "-" '{print $1}'`
main=`uname  -r | awk -F . '{print $1}'`
minor=`uname -r | awk -F . '{print $2}'`
uname -m | grep -q -E -i "aarch" && cpu=ARM64 || cpu=AMD64

bit=`uname -m`
if [[ $bit = x86_64 ]]; then
cpu=amd64
elif [[ $bit = aarch64 ]]; then
cpu=arm64
elif [[ $bit = s390x ]]; then
cpu=s390x
else
red "VPS的CPU架构为$bit 脚本不支持当前CPU架构，请使用amd64或arm64架构的CPU运行脚本" && exit
fi
vi=`systemd-detect-virt`

start(){
if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 2
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit
else
green "恭喜，添加TUN支持成功，现添加TUN守护功能" && sleep 4
cat>/root/tun.sh<<-\EOF
#!/bin/bash
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
EOF
chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN守护功能已启动"
fi
fi
fi
[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install curl)
[[ ! $(type -P sysctl) ]] && ($yumapt update;$yumapt install procps)
if [[ -z $(grep 'DiG 9' /etc/hosts) ]]; then
v4=$(curl -s4m6 ip.sb -k)
if [ -z $v4 ]; then
echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
fi
fi
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
}

instucore(){
lastvsion=`curl -s https://data.jsdelivr.com/v1/package/gh/EAimTY/tuic | sed -n 30p | tr -d ',"'`
wget https://github.com/EAimTY/tuic/releases/download/${lastvsion}/${lastvsion}-${bit}-unknown-linux-musl -O /usr/local/bin/tuic
if [[ -f '/usr/local/bin/tuic' ]]; then
chmod +x /usr/local/bin/tuic
blue "成功安装tuic内核版本：$(/usr/local/bin/tuic -v)\n"
else
red "安装tuic内核失败" && rm -rf tuic.sh && exit
fi
}

stclre(){
if [[ ! -f '/etc/tuic/tuic.json' ]]; then
green "未正常安装tuic" && exit
fi
green "tuic服务执行以下操作"
readp "1. 重启\n2. 关闭\n3. 启动\n请选择：" action
if [[ $action == "1" ]]; then
systemctl restart tuic
green "tuic服务重启\n"
elif [[ $action == "2" ]]; then
systemctl stop tuic
systemctl disable tuic
green "tuic服务关闭\n"
elif [[ $action == "3" ]]; then
systemctl enable tuic
systemctl start tuic
green "tuic服务开启\n"
else
red "输入错误,请重新选择" && stclre
fi
}

changeserv(){
if [[ -z $(systemctl status tuic 2>/dev/null | grep -w active) && ! -f '/etc/tuic/tuic.json' ]]; then
red "未正常安装tuic" && exit
fi
green "tuic配置变更选择如下:"
readp "1. 变更端口\n2. 变更密码\n3. 变更UUID\n4. 重新申请证书或变更证书路径\n5. 返回上层\n请选择：" choose
if [ $choose == "1" ];then
changeport
elif [ $choose == "2" ];then
changepswd
elif [ $choose == "3" ];then
changeuuid
elif [ $choose == "4" ];then
inscertificate
oldcer=`cat /etc/tuic/tuic.json 2>/dev/null | sed -n 6p | awk '{print $2}' | tr -d ',"'`
oldkey=`cat /etc/tuic/tuic.json 2>/dev/null | sed -n 7p | awk '{print $2}' | tr -d ',"'`
sed -i "s#$oldcer#${cert_path}#g" /etc/tuic/tuic.json
sed -i "s#$oldkey#${key_path}#g" /etc/tuic/tuic.json
olddomain=`cat /root/tuic/v2rayn.json 2>/dev/null | sed -n 3p | awk '{print $2}' | tr -d ',"'`
sed -i "s/$olddomain/${domain}/g" /etc/tuic/tuic.json
sed -i "s/$olddomain/${domain}/g" /root/tuic/v2rayn.json
sed -i "s/$olddomain/${domain}/g" /root/tuic/tuic.txt
sed -i "s/$olddomain/${domain}/g" /root/tuic/clash-meta.yaml
susstuic
elif [ $choose == "5" ];then
tu
else
red "请重新选择" && changeserv
fi
}

inscertificate(){
green "Tuic 协议证书申请方式如下："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 脚本自动申请 ${YELLOW}（默认）${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 自定义证书路径"
    echo ""
    read -rp "请输入选项 [1-2]: " certInput
    if [[ $certInput == 2 ]]; then
        read -p "请输入公钥文件 crt 的路径：" cert_path
        yellow "公钥文件 crt 的路径：$cert_path "
        read -p "请输入密钥文件 key 的路径：" key_path
        yellow "密钥文件 key 的路径：$key_path "
        read -p "请输入证书的域名：" domain
        yellow "证书域名：$domain"
    else
        cert_path="/root/ca/cert.crt"
        key_path="/root/ca/private.key"
        if [[ -f /root/ca/cert.crt && -f /root/ca/private.key ]] && [[ -s /root/ca/cert.crt && -s /root/ca/private.key ]] && [[ -f /root/ca/ca.log ]]; then
            domain=$(cat /root/ca/ca.log)
            green "检测到原有域名：$domain 的证书，正在应用"
        else
            if [[ -f /root/ca/cert.crt && -f /root/ca/private.key ]] && [[ -s /root/ca/cert.crt && -s /root/ca/private.key ]] && [[ -f /root/ca/ca.log ]]; then
blue "经检测，之前已使用此acme脚本申请过证书"
readp "1. 直接使用原来的证书（回车默认）\n2. 删除原来的证书，重新申请证书\n请选择：" certacme
if [ -z "${certacme}" ] || [ $certacme == "1" ];
then domain=$(cat /root/ca/ca.log)
blue "检测到的域名：$domain ，已直接引用\n"
elif [ $certacme == "2" ]; then
curl https://get.acme.sh | sh
bash /root/.acme.sh/acme.sh --uninstall
rm -rf /root/ca
rm -rf ~/.acme.sh acme.sh
sed -i '/--cron/d' /etc/crontab
[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh卸载完毕" || red "acme.sh卸载失败"
sleep 2
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
domain=$(cat /root/ca/ca.log)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/yca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
else
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
domain=$(cat /root/ca/ca.log)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/ca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
fi
fi
}

changeuuid(){
    olduuid=$(cat /etc/tuic/tuic.json 2>/dev/null | sed -n 4p | awk '{print $1}' | tr -d ':"')
    read -p "设置 tuic UUID（回车跳过为随机 UUID）：" uuid
    [[ -z $uuid ]] && uuid=$(cat /proc/sys/kernel/random/uuid)
    echo
    blue "当前正在使用的UUID：$uuid"
    echo
    [[ -z $uuid ]] && uuid=$(cat /proc/sys/kernel/random/uuid)
    sed -i "s/$olduuid/$uuid/g" /etc/tuic/tuic.json
    sed -i "s/$olduuid/$uuid/g" /root/tuic/v2rayn.json
    sed -i "s/$olduuid/$uuid/g" /root/tuic/tuic.txt
    sed -i "s/$olduuid/$uuid/g" /root/tuic/clash-meta.yaml

    systemctl stop tuic && systemctl start tuic
}

changepswd(){
    oldpasswd=$(cat /etc/tuic/tuic.json 2>/dev/null | sed -n 4p | awk '{print $2}' | tr -d '"')
    read -p "设置 tuic 密码（回车跳过为随机字符）：" passwd
    [[ -z $passwd ]] && passwd=$(date +%s%N | md5sum | cut -c 1-8)
    echo
    blue "当前正在使用的密码：$passwd"
    echo
    sed -i "s/$oldpasswd/$passwd/g" /etc/tuic/tuic.json
    sed -i "s/$oldpasswd/$passwd/g" /root/tuic/v2rayn.json
    sed -i "s/$oldpasswd/$passwd/g" /root/tuic/tuic.txt
    sed -i "s/$oldpasswd/$passwd/g" /root/tuic/clash-meta.yaml

     systemctl stop tuic && systemctl start tuic
}

changeport(){
    oldport=$(cat /etc/tuic/tuic.json 2>/dev/null | sed -n 's/.*"server": "\[::\]:\([0-9]*\)".*/\1/p')

    read -p "设置 tuic 端口[1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)

    until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 tuic 端口[1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done
    echo
    blue "当前正在使用的端口：$port"
    echo
    sed -i "s/$oldport/$port/g" /etc/tuic/tuic.json
    sed -i "s/$oldport/$port/g" /root/tuic/v2rayn.json
    sed -i "s/$oldport/$port/g" /root/tuic/tuic.txt
    sed -i "s/$oldport/$port/g" /root/tuic/clash-meta.yaml

    systemctl stop tuic && systemctl start tuic
}

acme(){
bash <(curl -L -s https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh)
}
cfwarp(){
wget -N --no-check-certificate https://gitlab.com/rwkgyg/cfwarp/raw/main/CFwarp.sh && bash CFwarp.sh
}

tuicstatus(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
[[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]] && wgcf=$(green "未启用") || wgcf=$(green "启用中")
if [[ -n $(systemctl status tuic 2>/dev/null | grep -w active) && -f '/etc/tuic/tuic.json' ]]; then
status=$(white "tuic状态：  \c";green "运行中";white "WARP状态：  \c";eval echo \$wgcf)
elif [[ -z $(systemctl status tuic 2>/dev/null | grep -w active) && -f '/etc/tuic/tuic.json' ]]; then
status=$(white "tuic状态：  \c";yellow "未启动,可尝试选择4，开启或者重启，依旧如此建议卸载重装tuic";white "WARP状态：  \c";eval echo \$wgcf)
else
status=$(white "tuic状态：  \c";red "未安装";white "WARP状态：  \c";eval echo \$wgcf)
fi
}

uptuicj(){
if [[ -z $(systemctl status tuic 2>/dev/null | grep -w active) && ! -f '/etc/tuic/tuic.json' ]]; then
red "未正常安装tuic" && exit
fi
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/tuic/tuic.sh
chmod +x /root/tuic.sh
ln -sf /root/tuic.sh /usr/bin/tu
green "tuic安装脚本升级成功" && tu
}

uptuic(){
if [[ -z $(systemctl status tuic 2>/dev/null | grep -w active) && ! -f '/etc/tuic/tuic.json' ]]; then
red "未正常安装tuic" && exit
fi
green "\n升级tuicy内核版本\n"
instucore
systemctl restart tuic
green "tuic内核版本升级成功" && tu
}

unins(){
systemctl stop tuic >/dev/null 2>&1
systemctl disable tuic >/dev/null 2>&1
rm -f /etc/systemd/system/tuic.service
rm -rf /usr/local/bin/tuic /etc/tuic /root/tuic /root/tuic.sh /usr/bin/tu
green "tuic卸载完成！"
}

tuicshare(){
    yellow "v2rayn 客户端配置文件 v2rayn.json 内容如下，并保存到 /root/tuic/v2rayn.json"
    cat /root/tuic/v2rayn.json
    yellow "Clash Meta 客户端配置文件已保存到 /root/tuic/clash-meta.yaml"
    yellow "Tuic 节点配置明文如下，并保存到 /root/tuic/tuic.txt"
    cat /root/tuic/tuic.txt
}

instuic(){
    warpv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warpv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $warpv4 =~ on|plus || $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
        realip
        systemctl start warp-go >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
    else
        realip
    fi

    if [[ ! ${SYSTEM} == "CentOS" ]]; then
        ${PACKAGE_UPDATE}
    fi
    ${PACKAGE_INSTALL} wget curl sudo

    wget https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/tuic/tuic-server-latest-linux-$bit -O /usr/local/bin/tuic
    if [[ -f "/usr/local/bin/tuic" ]]; then
        chmod +x /usr/local/bin/tuic
    else
        red "Tuic 内核安装失败！"
        exit 1
    fi

  green "Tuic 协议证书申请方式如下："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 脚本自动申请 ${YELLOW}（默认）${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 自定义证书路径"
    echo ""
    read -rp "请输入选项 [1-2]: " certInput
    if [[ $certInput == 2 ]]; then
        read -p "请输入公钥文件 crt 的路径：" cert_path
        yellow "公钥文件 crt 的路径：$cert_path "
        read -p "请输入密钥文件 key 的路径：" key_path
        yellow "密钥文件 key 的路径：$key_path "
        read -p "请输入证书的域名：" domain
        yellow "证书域名：$domain"
    else
        cert_path="/root/ca/cert.crt"
        key_path="/root/ca/private.key"
        if [[ -f /root/ca/cert.crt && -f /root/ca/private.key ]] && [[ -s /root/ca/cert.crt && -s /root/ca/private.key ]] && [[ -f /root/ca/ca.log ]]; then
            domain=$(cat /root/ca/ca.log)
            green "检测到原有域名：$domain 的证书，正在应用"
        else
            if [[ -f /root/ca/cert.crt && -f /root/ca/private.key ]] && [[ -s /root/ca/cert.crt && -s /root/ca/private.key ]] && [[ -f /root/ca/ca.log ]]; then
blue "经检测，之前已使用此acme脚本申请过证书"
readp "1. 直接使用原来的证书（回车默认）\n2. 删除原来的证书，重新申请证书\n请选择：" certacme
if [ -z "${certacme}" ] || [ $certacme == "1" ];
then domain=$(cat /root/ca/ca.log)
blue "检测到的域名：$domain ，已直接引用\n"
elif [ $certacme == "2" ]; then
curl https://get.acme.sh | sh
bash /root/.acme.sh/acme.sh --uninstall
rm -rf /root/ca
rm -rf ~/.acme.sh acme.sh
sed -i '/--cron/d' /etc/crontab
[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh卸载完毕" || red "acme.sh卸载失败"
sleep 2
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
domain=$(cat /root/ca/ca.log)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/yca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
else
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
domain=$(cat /root/ca/ca.log)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/ca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
fi
fi

    read -p "设置 tuic 端口[1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 tuic 端口[1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done

    read -p "设置 tuic UUID（回车跳过为随机 UUID）：" uuid
    [[ -z $uuid ]] && uuid=$(cat /proc/sys/kernel/random/uuid)

    read -p "设置 tuic 密码（回车跳过为随机字符）：" passwd
    [[ -z $passwd ]] && passwd=$(date +%s%N | md5sum | cut -c 1-8)

    green "正在配置 Tuic..."
    mkdir /etc/tuic >/dev/null 2>&1
    cat << EOF > /etc/tuic/tuic.json
{
    "server": "[::]:$port",
    "users": {
        "$uuid": "$passwd"
    },
    "certificate": "$cert_path",
    "private_key": "$key_path",
    "congestion_control": "bbr",
    "alpn": ["h3"],
    "log_level": "warn"
}
EOF
    mkdir /root/tuic >/dev/null 2>&1
    cat << EOF > /root/tuic/v2rayn.json
{
    "relay": {
        "server": "$domain:$port",
        "uuid": "$uuid",
        "password": "$passwd",
        "ip": "$ip",
        "congestion_control": "bbr",
        "alpn": ["h3"]
    },
    "local": {
        "server": "127.0.0.1:6080"
    },
    "log_level": "warn"
}
EOF
    cat << EOF > /root/tuic/tuic.txt
Sagernet、Nekobox 与 小火箭 配置说明（以下6项必填）：
{
    服务器地址：$domain
    服务器端口：$port
    UUID: $uuid
    密码：$passwd
    ALPN：h3
    UDP 转发：开启
    UDP 转发模式：QUIC
    拥塞控制：bbr
}
EOF
    cat << EOF > /root/tuic/clash-meta.yaml
mixed-port: 7890
external-controller: 127.0.0.1:9090
allow-lan: false
mode: rule
log-level: debug
ipv6: true
dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1
    - 114.114.114.114

proxies:
  - name: Misaka-tuic
    server: $domain
    port: $port
    type: tuic
    uuid: $uuid
    password: $passwd
    ip: $ip
    alpn: [h3]
    disable-sni: true
    reduce-rtt: true
    request-timeout: 8000
    udp-relay-mode: quic
    congestion-controller: bbr

proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - Misaka-tuic

rules:
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
EOF

    cat << EOF >/etc/systemd/system/tuic.service
[Unit]
Description=tuic Service
Documentation=https://gitlab.com/Misaka-blog/tuic-script
After=network.target
[Service]
User=root
ExecStart=/usr/local/bin/tuic -c /etc/tuic/tuic.json
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tuic
    systemctl start tuic
    if [[ -n $(systemctl status tuic 2>/dev/null | grep -w active) && -f '/etc/tuic/tuic.json' ]]; then
        green "tuic 服务启动成功"
    else
        red "tuic 服务启动失败，请运行systemctl status tuic查看服务状态并反馈，脚本退出" && exit 1
    fi
    red "======================================================================================"
    green "Tuic 代理服务安装完成"
    yellow "v2rayn 客户端配置文件 v2rayn.json 内容如下，并保存到 /root/tuic/v2rayn.json"
    cat /root/tuic/v2rayn.json
    yellow "Clash Meta 客户端配置文件已保存到 /root/tuic/clash-meta.yaml"
    yellow "Tuic 节点配置明文如下，并保存到 /root/tuic/tuic.txt"
    cat /root/tuic/tuic.txt
    sleep 2
}
start_menu(){
tuicstatus
clear
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "  1. 安装tuic（必选）"
green "  2. 卸载tuic"
white "----------------------------------------------------------------------------------"
green "  3. 变更配置（端口、密码、UUID、证书）"
green "  4. 关闭、开启、重启tuic"
green "  5. 更新tuic安装脚本"
green "  6. 更新tuic内核版本"
white "----------------------------------------------------------------------------------"
green "  7. 显示当前tuic配置明文、V2rayN配置文件"
green "  8. ACME证书管理菜单"
green "  9. 安装WARP（可选）"
green "  0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [[ -n $(systemctl status tuic 2>/dev/null | grep -w active) && -f '/etc/tuic/tuic.json' ]]; then
if [ "${tuV}" = "${remoteV}" ]; then
echo -e "当前 tuic 安装脚本版本号：${bblue}${tuV}${plain} ，已是最新版本\n"
else
echo -e "当前 tuic 安装脚本版本号：${bblue}${tuV}${plain}"
echo -e "检测到最新 tuic 安装脚本版本号：${yellow}${remoteV}${plain} ，可选择5进行更新\n"
fi
if [ "$vsion" = "$lastvsion" ]; then
echo -e "当前 tuic 已安装内核版本号：${bblue}${vsion}${plain} ，已是官方最新版本"
else
echo -e "当前 tuic 已安装内核版本号：${bblue}${vsion}${plain}"
echo -e "检测到最新 tuic 内核版本号：${yellow}${lastvsion}${plain} ，可选择6进行更新"
fi
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white "VPS系统信息如下："
white "操作系统：  $(blue "$op")" && white "内核版本：  $(blue "$version")" && white "CPU架构：   $(blue "$cpu")" && white "虚拟化类型：$(blue "$vi")"
white "$status"
echo
readp "请输入数字:" Input
case "$Input" in
 1 ) instuic;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) stclre;;
 5 ) uptuicj;;
 6 ) uptuic;;
 7 ) tuicshare;;
 8 ) acme;;
 9 ) cfwarp;;
 * ) exit
esac
}
if [ $# == 0 ]; then
start
lastvsion=v`curl -s https://data.jsdelivr.com/v1/package/gh/EAimTY/tuic | sed -n 30p | tr -d ',"' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+'`
vsion=v`/usr/local/bin/tuic -v 2>/dev/null`
start_menu
fi
