#!/bin/bash
hyV="22.11.12 V 5.0"
remoteV=`wget -qO- https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/hysteria/hysteria.sh | sed  -n 2p | cut -d '"' -f 2`
chmod +x /root/hysteria.sh
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
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

wgcfgo(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
sureipadress
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
sureipadress
systemctl start wg-quick@wgcf >/dev/null 2>&1
fi
}

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
[[ $(type -P lsof) ]] || (yellow "检测到lsof未安装，升级安装中" && $yumapt update;$yumapt install lsof)
[[ ! $(type -P qrencode) ]] && ($yumapt update;$yumapt install qrencode)
[[ ! $(type -P sysctl) ]] && ($yumapt update;$yumapt install procps)
[[ ! $(type -P iptables) ]] && ($yumapt update;$yumapt install iptables-persistent)
[[ ! $(type -P python3) ]] && (yellow "检测到python3未安装，升级安装中" && $yumapt update;$yumapt install python3)
if [[ -z $(grep 'DiG 9' /etc/hosts) ]]; then
v4=$(curl -s4m5 https://ip.gs -k)
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

inshy(){
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
green "已安装hysteria，重装请先执行卸载功能" && exit
fi
if [[ $release = Centos ]]; then
if [[ ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
fi
yum install epel-release -y
else
$yumapt update
fi
systemctl stop hysteria-server >/dev/null 2>&1
systemctl disable hysteria-server >/dev/null 2>&1
rm -rf /usr/local/bin/hysteria /etc/hysteria /root/HY
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/hysteria/install_server.sh && bash install_server.sh
if [[ -f '/usr/local/bin/hysteria' ]]; then
blue "成功安装hysteria内核版本：$(/usr/local/bin/hysteria -v | awk 'NR==1 {print $3}')\n"
else
red "安装hysteria内核失败" && rm -rf install_server.sh && exit
fi
rm -rf install_server.sh
}

inscertificate(){
green "hysteria协议证书申请方式选择如下:"
readp "1. www.bing.com自签证书（回车默认）\n2. acme一键申请证书脚本（支持常规80端口模式与dns api模式）或已放置在/root/ca目录的自定义证书\n请选择：" certificate
if [ -z "${certificate}" ] || [ $certificate == "1" ]; then
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/private.key -out /etc/hysteria/cert.crt -subj "/CN=www.bing.com"
ym=www.bing.com
certificatep='/etc/hysteria/private.key'
certificatec='/etc/hysteria/cert.crt'
blue "已确认证书模式: www.bing.com自签证书\n"
elif [ $certificate == "2" ]; then
if [[ -f /root/ca/cert.crt && -f /root/ca/private.key ]] && [[ -s /root/ca/cert.crt && -s /root/ca/private.key ]]; then
blue "经检测，root/ca目录下有证书文件（cert.crt与private.key）"
readp "1. 直接使用root/ca目录下申请过证书（回车默认）\n2. 删除原来的证书，重新申请acme证书\n请选择：" certacme
if [ -z "${certacme}" ] || [ $certacme == "1" ]; then
if [[ -f /root/ca/ca.log ]]; then
ym=$(cat /root/ca/ca.log)
blue "检测到的域名：$ym ，已直接引用\n"
else
green "无acme脚本申请证书记录，当前为自定义证书模式"
readp "请输入已解析完成的域名:" ym
blue "输入的域名：$ym，已直接引用\n"
fi
elif [ $certacme == "2" ]; then
rm -rf /root/ca
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
ym=$(cat /root/ca/ca.log 2>/dev/null)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/ca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
else
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
ym=$(cat /root/ca/ca.log 2>/dev/null)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/ca/cert.crt && ! -s /root/ca/private.key ]]; then
red "域名申请失败，脚本退出" && exit
fi
fi
certificatep='/root/ca/private.key'
certificatec='/root/ca/cert.crt'
else 
red "输入错误，请重新选择" && inscertificate
fi
}

inspr(){
green "hysteria的传输协议选择如下:"
readp "1. udp（支持范围端口跳跃功能，回车默认）\n2. wechat-video\n3. faketcp（仅支持linux或者安卓客户端且需要root权限）\n请选择：" protocol
if [ -z "${protocol}" ] || [ $protocol == "1" ];then
hysteria_protocol="udp"
elif [ $protocol == "2" ];then
hysteria_protocol="wechat-video"
elif [ $protocol == "3" ];then
hysteria_protocol="faketcp"
else 
red "输入错误，请重新选择" && inspr
fi
echo
blue "已确认传输协议: ${hysteria_protocol}\n"
}

insport(){
dports(){
readp "\n设置多端口(建议10000-65535之间，每次仅增加一个)：" manyports
iptables -t nat -A PREROUTING -p udp --dport $manyports  -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $manyports  -j DNAT --to-destination :$port
blue "\n已确认转发的多端口：$manyports\n"
echo -n $manyports, >> /root/HY/mports
}

arports(){
readp "\n添加多端口，继续按回车，退出按任意键：" choose
if [[ -z $choose ]]; then
until [[ -n $choose ]] && sed -i 's/.$//' /root/HY/mports
do
[[ -z $choose ]] && dports && readp "\n是否继续添加多端口？继续按回车，退出按任意键：" choose
done
fi
}

fports(){
readp "\n添加一个范围端口的起始端口(建议10000-65535之间)：" firstudpport
readp "\n添加一个范围端口的末尾端口(建议10000-65535之间，要比上面起始端口大)：" endudpport
if [[ $firstudpport -ge $endudpport ]]; then
until [[ $firstudpport -le $endudpport ]]
do
[[ $firstudpport -ge $endudpport ]] && yellow "\n起始端口小于末尾端口啦，人才！请重新输入起始/末尾端口" && readp "\n添加一个范围端口的起始端口(建议10000-65535之间)：" firstudpport && readp "\n添加一个范围端口的末尾端口(建议10000-65535之间，要比上面起始端口大)：" endudpport
done
fi
iptables -t nat -A PREROUTING -p udp --dport $firstudpport:$endudpport  -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $firstudpport:$endudpport  -j DNAT --to-destination :$port
blue "\n已确认转发的范围端口：$firstudpport 到 $endudpport\n"
}

iptables -t nat -F PREROUTING >/dev/null 2>&1
rm -rf /root/HY/mports
readp "设置hysteria转发主端口[1-65535]（回车跳过为2000-65535之间的随机端口）：" port
if [[ -z $port ]]; then
port=$(shuf -i 2000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义hysteria转发主端口:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义hysteria转发主端口:" port
done
fi
blue "\n已确认转发主端口：$port\n"
if [[ ${hysteria_protocol} == "udp" || $(cat /etc/hysteria/config.json 2>/dev/null | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}') == "udp" ]]; then
green "\n经检测，当前选择的是udp协议，可选择支持范围端口自动跳跃功能（默认每10秒切换）\n"
readp "1. 继续使用默认单端口（回车默认）\n2. 使用范围端口（支持自动跳跃功能）\n请选择：" choose
if [ -z "${choose}" ] || [ $choose == "1" ]; then
echo
elif [ $choose == "2" ]; then
fports
else
red "输入错误，请重新选择" && insport
fi
iptables -t nat -A PREROUTING -p udp --dport $port  -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $port  -j DNAT --to-destination :$port
fi
netfilter-persistent save >/dev/null 2>&1
}

inspswd(){
readp "设置hysteria验证密码，必须为6位字符以上（回车跳过为随机6位字符）：" pswd
if [[ -z ${pswd} ]]; then
pswd=`date +%s%N |md5sum | cut -c 1-6`
else
if [[ 6 -ge ${#pswd} ]]; then
until [[ 6 -le ${#pswd} ]]
do
[[ 6 -ge ${#pswd} ]] && yellow "\n用户名必须为6位字符以上！请重新输入" && readp "\n设置hysteria密码：" pswd
done
fi
fi
blue "已确认验证密码：${pswd}\n"
}

portss(){
manyports=`cat /root/HY/mports 2>/dev/null`
if [[ -z $firstudpport && -z $manyports ]]; then
clport=$port
elif [[ -n $firstudpport && -n $manyports ]]; then
clport="$port,$manyports,$firstudpport-$endudpport"
elif [[ -z $firstudpport ]]; then
clport="$port,$manyports"
elif [[ -z $manyports ]]; then
clport="$port,$firstudpport-$endudpport"
fi
}

insconfig(){
green "设置配置文件中……，稍等5秒"
v4=$(curl -s4m5 https://ip.gs -k)
[[ -z $v4 ]] && rpip=64 || rpip=46
cat <<EOF > /etc/hysteria/config.json
{
"listen": ":${port}",
"protocol": "${hysteria_protocol}",
"resolve_preference": "${rpip}",
"auth": {
"mode": "password",
"config": {
"password": "${pswd}"
}
},
"alpn": "h3",
"cert": "${certificatec}",
"key": "${certificatep}"
}
EOF

sureipadress(){
ip=$(curl -s4m5 https://ip.gs -k) || ip=$(curl -s6m5 https://ip.gs -k)
[[ -z $(echo $ip | grep ":") ]] && ymip=$ip || ymip="[$ip]" 
}

wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
sureipadress
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
sureipadress
systemctl start wg-quick@wgcf >/dev/null 2>&1
fi

if [[ $ym = www.bing.com ]]; then
ins=true
else
ym=$(cat /root/ca/ca.log)
ymip=$ym;ins=false
fi

portss
cat <<EOF > /root/HY/acl/v2rayn.json
{
"server": "${ymip}:${clport}",
"protocol": "${hysteria_protocol}",
"up_mbps": 200,
"down_mbps": 1000,
"alpn": "h3",
"acl": "acl/routes.acl",
"mmdb": "acl/Country.mmdb",
"http": {
"listen": "127.0.0.1:10809",
"timeout" : 300,
"disable_udp": false
},
"socks5": {
"listen": "127.0.0.1:10808",
"timeout": 300,
"disable_udp": false
},
"auth_str": "${pswd}",
"server_name": "${ym}",
"insecure": ${ins},
"retry": 3,
"retry_interval": 3,
"hop_interval": 10

}
EOF
}

unins(){
systemctl stop hysteria-server.service >/dev/null 2>&1
systemctl disable hysteria-server.service >/dev/null 2>&1
rm -f /lib/systemd/system/hysteria-server.service /lib/systemd/system/hysteria-server@.service
rm -rf /usr/local/bin/hysteria /etc/hysteria /root/HY /root/install_server.sh /root/hysteria.sh /usr/bin/hy
sed -i '/systemctl restart hysteria-server/d' /etc/crontab
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
green "hysteria卸载完成！"
}

uphysteriacore(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
wget -N https://raw.githubusercontent.com/apernet/hysteria/master/install_server.sh && bash install_server.sh
systemctl restart hysteria-server
VERSION="$(/usr/local/bin/hysteria -v | awk 'NR==1 {print $3}')"
blue "当前hysteria内核版本号：$VERSION"
rm -rf install_server.sh
}

stclre(){
if [[ ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
green "hysteria服务执行以下操作"
readp "1. 重启\n2. 关闭\n3. 启动\n请选择：" action
if [[ $action == "1" ]];then
systemctl restart hysteria-server
green "hysteria服务重启成功"
hysteriastatus
white "$status\n"
elif [[ $action == "2" ]];then
systemctl stop hysteria-server
systemctl disable hysteria-server
green "hysteria服务关闭成功"
hysteriastatus
white "$status\n"
elif [[ $action == "3" ]];then
systemctl enable hysteria-server
systemctl start hysteria-server
green "hysteria服务开启成功"
hysteriastatus
white "$status\n"
else
red "输入错误,请重新选择" && stclre
fi
}

uphy(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/hysteria/hysteria.sh
chmod +x /root/hysteria.sh 
ln -sf /root/hysteria.sh /usr/bin/hy
green "安装脚本升级成功" && hy
}

cfwarp(){
wget -N --no-check-certificate https://gitlab.com/rwkgyg/cfwarp/raw/main/CFwarp.sh && bash CFwarp.sh
}

bbr(){
wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

acme(){
bash <(curl -L -s https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh)
}

changepr(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
noprotocol=`cat /etc/hysteria/config.json 2>/dev/null | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}'`
echo
blue "当前正在使用的协议：$noprotocol"
echo
inspr
sed -i "s/$noprotocol/$hysteria_protocol/g" /etc/hysteria/config.json
sed -i "3s/$noprotocol/$hysteria_protocol/g" /root/HY/acl/v2rayn.json
sed -i "s/$noprotocol/$hysteria_protocol/g" /root/HY/URL.txt
systemctl restart hysteria-server
blue "hysteria代理服务的协议已由 $noprotocol 更换为 $hysteria_protocol ，配置已更新 "
hysteriashare
}

changecertificate(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
certclient(){
sureipadress(){
ip=$(curl -s4m5 https://ip.gs -k) || ip=$(curl -s6m5 https://ip.gs -k)
certificate=`cat /etc/hysteria/config.json 2>/dev/null | grep cert | awk '{print $2}' | awk -F '"' '{ print $2}'`
if [[ $certificate = '/etc/hysteria/cert.crt' ]]; then
if [[ -n $(curl -s6m5 https://ip.gs -k) ]]; then
oldserver=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}' | grep -o '\[.*\]' | cut -d '[' -f2|cut -d ']' -f1`
else
oldserver=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| cut -d ':' -f 1`
fi
else
oldserver=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| cut -d ':' -f 1`
fi
if [[ $certificate = '/etc/hysteria/cert.crt' ]]; then
ym=$(cat /root/ca/ca.log)
ymip=$(cat /root/ca/ca.log)
else
ym=www.bing.com
ymip=$ip
fi
}
wgcfgo
}
servername=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server_name | awk '{print $2}' | awk -F '"' '{ print $2}'`
certificate=`cat /etc/hysteria/config.json 2>/dev/null | grep cert | awk '{print $2}' | awk -F '"' '{ print $2}'`
if [[ $certificate = '/etc/hysteria/cert.crt' ]]; then
certificatepp='/etc/hysteria/private.key'
certificatecc='/etc/hysteria/cert.crt'
blue "当前正在使用的证书：bing自签证书，可更换为acme申请证书或已上传root/ca目录的自定义证书"
echo
readp "是否切换？（回车为是。其他选择为否，并返回主菜单）\n请选择：" choose
if [ -z "${choose}" ]; then
if [[ -f /root/ca/cert.crt && -f /root/ca/private.key ]] && [[ -s /root/ca/cert.crt && -s /root/ca/private.key ]]; then
blue "经检测，root/ca目录下有证书文件（cert.crt与private.key）"
readp "1. 直接使用root/ca目录下申请过证书（回车默认）\n2. 删除原来的证书，重新申请acme证书\n请选择：" certacme
if [ -z "${certacme}" ] || [ $certacme == "1" ]; then
if [[ -f /root/ca/ca.log ]]; then
ym=$(cat /root/ca/ca.log)
blue "检测到的域名：$ym ，已直接引用\n"
else
green "无acme脚本申请证书记录，当前为自定义证书模式"
readp "请输入已解析完成的域名:" ym
blue "输入的域名：$ym，已直接引用\n"
fi
elif [ $certacme == "2" ]; then 
curl https://get.acme.sh | sh
bash /root/.acme.sh/acme.sh --uninstall
rm -rf /root/ca
rm -rf ~/.acme.sh acme.sh
sed -i '/--cron/d' /etc/crontab
[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh卸载完毕" || red "acme.sh卸载失败"
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
ym=$(cat /root/ca/ca.log 2>/dev/null)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/ca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
else
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
ym=$(cat /root/ca/ca.log 2>/dev/null)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/ca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
certificatep='/root/ca/private.key'
certificatec='/root/ca/cert.crt'
certclient
sed -i '21s/true/false/g' /root/HY/acl/v2rayn.json
sed -i 's/true/false/g' /root/HY/URL.txt
else
hy
fi
else
certificatepp='/root/ca/private.key'
certificatecc='/root/ca/cert.crt'
blue "当前正在使用的证书：acme申请的证书，可更换为bing自签证书"
echo
readp "是否切换？（回车为是。其他选择为否，并返回主菜单）\n请选择：" choose
if [ -z "${choose}" ]; then
if [[ -f /etc/hysteria/cert.crt && -f /etc/hysteria/private.key ]]; then
ym=www.bing.com
blue "经检测，之前已申请过自签证书，已直接引用\n"
else
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
openssl req -new -x509 -days 36500 -key /etc/hysteria/private.key -out /etc/hysteria/cert.crt -subj "/CN=www.bing.com"
ym=www.bing.com
fi
certificatep='/etc/hysteria/private.key'
certificatec='/etc/hysteria/cert.crt'
certclient
sed -i '21s/false/true/g' /root/HY/acl/v2rayn.json
sed -i 's/false/true/g' /root/HY/URL.txt
else
hy
fi
fi

sureipadress(){
if [[ $certificate = '/etc/hysteria/cert.crt' && -n $(curl -s6m5 https://ip.gs -k) ]]; then
sed -i "2s/\[$oldserver\]/${ymip}/g" /root/HY/acl/v2rayn.json
sed -i "s/\[$oldserver\]/${ymip}/g" /root/HY/URL.txt
elif [[ $certificate = '/root/ca/cert.crt' && -n $(curl -s6m5 https://ip.gs -k) ]]; then
sed -i "2s/$oldserver/\[${ymip}\]/g" /root/HY/acl/v2rayn.json
sed -i "s/$oldserver/\[${ymip}\]/" /root/HY/URL.txt
elif [[ $certificate = '/root/ca/cert.crt' && -z $(curl -s6m5 https://ip.gs -k) ]]; then
sed -i "2s/$oldserver/${ymip}/g" /root/HY/acl/v2rayn.json
sed -i "s/$oldserver/${ymip}/" /root/HY/URL.txt
elif [[ $certificate = '/etc/hysteria/cert.crt' && -z $(curl -s6m5 https://ip.gs -k) ]]; then
sed -i "2s/$oldserver/${ymip}/g" /root/HY/acl/v2rayn.json
sed -i "s/$oldserver/${ymip}/g" /root/HY/URL.txt
fi
}
wgcfgo
sed -i "s/$servername/$ym/g" /root/HY/acl/v2rayn.json
sed -i "s/$servername/$ym/g" /root/HY/URL.txt
sed -i "s!$certificatepp!$certificatep!g" /etc/hysteria/config.json
sed -i "s!$certificatecc!$certificatec!g" /etc/hysteria/config.json
systemctl restart hysteria-server
hysteriashare
}

changeip(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
ipv6=$(curl -s6m5 https://ip.gs -k) 
ipv4=$(curl -s4m5 https://ip.gs -k)
chip(){
rpip=`cat /etc/hysteria/config.json 2>/dev/null | grep resolve_preference | awk '{print $2}' | awk -F '"' '{ print $2}'`
sed -i "4s/$rpip/$rrpip/g" /etc/hysteria/config.json
systemctl restart hysteria-server
}
green "切换IPV4/IPV6出站优先级选择如下:"
readp "1. IPV4优先\n2. IPV6优先\n3. 仅IPV4\n4. 仅IPV6\n请选择：" choose
if [[ $choose == "1" && -n $ipv4 ]]; then
rrpip="46" && chip && v4v6="IPV4优先：$ipv4"
elif [[ $choose == "2" && -n $ipv6 ]]; then
rrpip="64" && chip && v4v6="IPV6优先：$ipv6"
elif [[ $choose == "3" && -n $ipv4 ]]; then
rrpip="4" && chip && v4v6="仅IPV4：$ipv4"
elif [[ $choose == "4" && -n $ipv6 ]]; then
rrpip="6" && chip && v4v6="仅IPV6：$ipv6"
else 
red "当前不存在你选择的IPV4/IPV6地址，或者输入错误" && changeip
fi
blue "确定当前已更换的IP优先级：${v4v6}\n"
}

changepswd(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
oldpswd=`cat /etc/hysteria/config.json 2>/dev/null | grep -w password | awk '{print $2}' | awk -F '"' '{ print $2}' | sed -n 2p`
echo
blue "当前正在使用的验证密码：$oldpswd"
echo
inspswd
sed -i "8s/$oldpswd/$pswd/g" /etc/hysteria/config.json
sed -i "19s/$oldpswd/$pswd/g" /root/HY/acl/v2rayn.json
sed -i "s/$oldpswd/$pswd/g" /root/HY/URL.txt
systemctl restart hysteria-server
blue "hysteria代理服务的验证密码已由 $oldpswd 更换为 $pswd ，配置已更新 "
hysteriashare
}

changeport(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
oldport=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| awk -F ':' '{ print $NF}'`
servport=`cat /etc/hysteria/config.json 2>/dev/null  | awk '{print $2}' | sed -n 2p | tr -d ',:"'`
echo
blue "当前在使用的转发端口：$oldport 已全部重置，请赶紧设置哦"
echo
insport
portss
sed -i "2s/$servport/$port/g" /etc/hysteria/config.json
sed -i "2s/$oldport/$clport/g" /root/HY/acl/v2rayn.json
sed -i "s/$servport/$port/g" /root/HY/URL.txt
systemctl restart hysteria-server
blue "hysteria代理服务的转发主端口已由 $servport 更换为 $port ，配置已更新 "
hysteriashare
}

changeserv(){
green "hysteria配置变更选择如下:"
readp "1. 切换IP出站优先级（四模式）\n2. 切换传输协议类型\n3. 切换证书类型(支持/root/ca路径上传自定义证书)\n4. 更换验证密码\n5. 变更主端口或者开启范围端口范围跳跃功能（将重置所有端口）\n6. 返回上层\n请选择：" choose
if [ $choose == "1" ];then
changeip
elif [ $choose == "2" ];then
changepr
elif [ $choose == "3" ];then
changecertificate
elif [ $choose == "4" ];then
changepswd
elif [ $choose == "5" ];then
changeport
elif [ $choose == "6" ];then
hy
else 
red "请重新选择" && changeserv
fi
}

inshysteria(){
inshy ; inscertificate
mkdir -p /root/HY/acl
inspr ; insport ; inspswd
if [[ ! $vi =~ lxc|openvz ]]; then
sysctl -w net.core.rmem_max=8000000
sysctl -p
fi
insconfig
systemctl enable hysteria-server >/dev/null 2>&1
systemctl start hysteria-server >/dev/null 2>&1
systemctl restart hysteria-server >/dev/null 2>&1
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
sed -i '/systemctl restart hysteria-server/d' /etc/crontab
echo "0 4 * * * systemctl restart hysteria-server >/dev/null 2>&1" >> /etc/crontab
chmod +x /root/hysteria.sh 
ln -sf /root/hysteria.sh /usr/bin/hy
wget -NP /root/HY https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/hysteria/GetRoutes.py 
python3 /root/HY/GetRoutes.py
mv -f Country.mmdb routes.acl /root/HY/acl
hysteriastatus
white "$status\n"
sureipadress(){
certificate=`cat /etc/hysteria/config.json 2>/dev/null | grep cert | awk '{print $2}' | awk -F '"' '{ print $2}'`
if [[ $certificate = '/etc/hysteria/cert.crt' ]]; then
ip=$(curl -s4m5 https://ip.gs -k) || ip=$(curl -s6m5 https://ip.gs -k)
[[ -z $(echo $ip | grep ":") ]] && ymip=$ip || ymip="[$ip]"
else
ymip=$(cat /root/ca/ca.log)
fi
}
wgcfgo
url="hysteria://${ymip}:${port}?protocol=${hysteria_protocol}&auth=${pswd}&peer=${ym}&insecure=${ins}&upmbps=200&downmbps=1000&alpn=h3#hysteria-${ymip}"
echo ${url} > /root/HY/URL.txt
red "======================================================================================"
green "hysteria代理服务安装完成，生成脚本的快捷方式为 hy" && sleep 3
blue "v2rayn客户端配置文件v2rayn.json及代理规则文件保存到 /root/HY/acl\n"
yellow "$(cat /root/HY/acl/v2rayn.json)\n"
blue "分享链接保存到 /root/HY/URL.txt" && sleep 3
yellow "${url}\n"
green "二维码分享链接如下(SagerNet / Matsuri / 小火箭)" && sleep 3
qrencode -o - -t ANSIUTF8 "$(cat /root/HY/URL.txt)"
else
red "hysteria代理服务安装失败，请运行 systemctl status hysteria-server 查看服务日志" && exit
fi
}

hysteriastatus(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
[[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]] && wgcf=$(green "未启用") || wgcf=$(green "启用中")
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
noprotocol=`cat /etc/hysteria/config.json 2>/dev/null | grep protocol | awk '{print $2}' | awk -F '"' '{ print $2}'`
rpip=`cat /etc/hysteria/config.json 2>/dev/null | grep resolve_preference | awk '{print $2}' | awk -F '"' '{ print $2}'`
v4=$(curl -s4m5 https://ip.gs -k)
v6=$(curl -s6m5 https://ip.gs -k)
[[ -z $v4 ]] && showv4='IPV4地址丢失，请切换至IPV6或者重装hysteria' || showv4=$v4
[[ -z $v6 ]] && showv6='IPV6地址丢失，请切换至IPV4或者重装hysteria' || showv6=$v6
if [[ $rpip = 64 ]]; then
v4v6="IPV6优先：$showv6"
elif [[ $rpip = 46 ]]; then
v4v6="IPV4优先：$showv4"
elif [[ $rpip = 4 ]]; then
v4v6="仅IPV4：$showv4"
elif [[ $rpip = 6 ]]; then
v4v6="仅IPV6：$showv6"
fi
oldport=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| awk -F ':' '{ print $NF}'`
status=$(white "hysteria状态：\c";green "运行中";white "hysteria协议：\c";green "$noprotocol";white "优先出站IP：  \c";green "$v4v6   \c";white "可代理端口：\c";green "$oldport";white "WARP状态：    \c";eval echo \$wgcf)
elif [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
status=$(white "hysteria状态：\c";yellow "未启动,可尝试选择4，开启或者重启，依旧如此建议卸载重装hysteria";white "WARP状态：    \c";eval echo \$wgcf)
else
status=$(white "hysteria状态：\c";red "未安装";white "WARP状态：    \c";eval echo \$wgcf)
fi
}

hysteriashare(){
if [[ -z $(systemctl status hysteria-server 2>/dev/null | grep -w active) || ! -f '/etc/hysteria/config.json' ]]; then
red "未正常安装hysteria!" && exit
fi
red "======================================================================================"
oldport=`cat /root/HY/acl/v2rayn.json 2>/dev/null | grep -w server | awk '{print $2}' | awk -F '"' '{ print $2}'| awk -F ':' '{ print $NF}'`
green "\n当前hysteria代理正在使用的端口：" && sleep 2
blue "$oldport\n"
green "当前v2rayn客户端配置文件v2rayn.json内容如下，保存到 /root/HY/acl/v2rayn.json\n" && sleep 2
yellow "$(cat /root/HY/acl/v2rayn.json)\n"
green "当前hysteria节点分享链接如下，保存到 /root/HY/URL.txt" && sleep 2
yellow "$(cat /root/HY/URL.txt)\n"
green "当前hysteria节点二维码分享链接如下(SagerNet / Matsuri / 小火箭)" && sleep 2
qrencode -o - -t ANSIUTF8 "$(cat /root/HY/URL.txt)"
}

start_menu(){
hysteriastatus
clear
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1. 安装hysteria（必选）" 
green " 2. 卸载hysteria"
white "----------------------------------------------------------------------------------"
green " 3. 变更配置（IP优先级、传输协议、证书类型、验证密码、范围端口）" 
green " 4. 关闭、开启、重启hysteria"   
green " 5. 更新hysteria安装脚本"  
green " 6. 更新hysteria内核"
white "----------------------------------------------------------------------------------"
green " 7. 显示hysteria分享链接、V2rayN配置文件、二维码（变更配置后可再次选择输出新的配置信息）"
green " 8. acme证书管理菜单"
green " 9. 安装warp（可选）"
green " 10. 安装BBR+FQ加速（可选）"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
if [ "${hyV}" = "${remoteV}" ]; then
echo -e "当前 hysteria 安装脚本版本号：${bblue}${hyV}${plain} ，已是最新版本\n"
else
echo -e "当前 hysteria 安装脚本版本号：${bblue}${hyV}${plain}"
echo -e "检测到最新 hysteria 安装脚本版本号：${yellow}${remoteV}${plain} ，可选择5进行更新\n"
fi
loVERSION="$(/usr/local/bin/hysteria -v | awk 'NR==1 {print $3}')"
hyVERSION="v$(curl -s https://data.jsdelivr.com/v1/package/gh/HyNetwork/Hysteria | sed -n 4p | tr -d ',"' | awk '{print $1}')"
if [ "${loVERSION}" = "${hyVERSION}" ]; then
echo -e "当前 hysteria 已安装内核版本号：${bblue}${loVERSION}${plain} ，已是最新版本"
else
echo -e "当前 hysteria 已安装内核版本号：${bblue}${loVERSION}${plain}"
echo -e "检测到最新 hysteria 内核版本号：${yellow}${hyVERSION}${plain} ，可选择6进行更新"
fi
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white "VPS系统信息如下："
white "操作系统:     $(blue "$op")" && white "内核版本:     $(blue "$version")" && white "CPU架构 :     $(blue "$cpu")" && white "虚拟化类型:   $(blue "$vi")" && white "TCP算法:      $(blue "$bbr")"
white "$status"
echo
readp "请输入数字:" Input
case "$Input" in     
 1 ) inshysteria;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) stclre;;
 5 ) uphy;; 
 6 ) uphysteriacore;;
 7 ) hysteriashare;;
 8 ) acme;;
 9 ) cfwarp;;
 10 ) bbr;;
 * ) exit 
esac
}
if [ $# == 0 ]; then
start
start_menu
fi
