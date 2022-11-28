#!/bin/bash
hyygV="22.11.28 V 1.0"
remoteV=`wget -qO- https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/install.sh | sed  -n 2p | cut -d '"' -f 2`
chmod +x /root/install.sh
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

gengxin(){
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/install.sh
chmod +x /root/install.sh 
ln -sf /root/install.sh /usr/bin/ES
green "install安装脚本升级成功" && ES
}

nginx(){
yum update -y || apt update -y
yum install nginx curl wget -y || apt install nginx curl wget -y
systemctl start nginx.service
systemctl enable nginx.service
green "nginx安装成功"
}

acme(){
bash <(curl -L -s https://github.com/Jason6111/ExpressSetup/raw/main/acme.sh)
}

x-ui(){
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
}

x-uimogai() {
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
rm -f /usr/local/x-ui/bin/xray-linux-amd64
wget --no-check-certificate -O /usr/local/x-ui/bin/xray-linux-amd64 "https://cdn.jsdelivr.net/gh/Jason6111/ExpressSetup@main/xray-linux-amd64"
sudo chmod 755 /usr/local/x-ui/bin/xray-linux-amd64
systemctl restart x-ui
}

nezhamianban() {
curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh  -o nezha.sh && chmod +x nezha.sh
sudo ./nezha.sh
}

bbrInstall(){
bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
}

xrayInstall() {
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
}

mtp() {
bash <(https://github.com/Jason6111/ExpressSetup/raw/main/mtp.sh)
}

zhuanfa() {
echo "=============================================================="
echo "选择机器"
echo "1.国外机"
echo "2.国内机"
echo "=============================================================="
	read -r -p "请选择:" installzhuanfa
	if [[ "${installzhuanfa}" == "1" ]]; then
		wget --no-check-certificate -qO natcfg.sh https://raw.githubusercontent.com/arloor/iptablesUtils/master/natcfg.sh && bash natcfg.sh 
	else
		wget --no-check-certificate -qO natcfg.sh http://www.arloor.com/sh/iptablesUtils/natcfg.sh && bash natcfg.sh
	fi
}


start_menu()
installstatus
clear
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1.更新脚本" 
green " 2.安装nginx有宝塔的不用安装"
green " 3.ssl证书(请先确保端口打开)"
green " 4.安装x-ui"
green " 5.安装x-ui并替换文件"
green " 6.转发救机"
green " 7.安装bbr"
green " 8.一键Xray"
green " 9.安装哪吒探针"
green " 10.电报代理“
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white "VPS系统信息如下："
white "操作系统:     $(blue "$op")" && white "内核版本:     $(blue "$version")" && white "CPU架构 :     $(blue "$cpu")" && white "虚拟化类型:   $(blue "$vi")"
white "$status"
echo
readp "请输入数字:" Input
case "$Input" in
 1 ) gengxin;;
 2 ) nginx;;
 3 ) acme;;
 4 ) x-ui;;
 5 ) x-uimogai;; 
 6 ) zhuanfa;;
 7 ) bbrInstall;;
 8 ) xrayInstall;;
 9 ) nezhaianban;;
 10 ）mtp;;
 * ) exit 
esac
}
if [ $# == 0 ]; then
start
start_menu
fi
