#!/bin/bash
esV="22.12.9 V 1.0"
remoteV=`wget -qO- https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/esinstall.sh | sed  -n 2p | cut -d '"' -f 2`
chmod +x /root/esinstall.sh
ln -sf /root/esinstall.sh /usr/bin/es
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
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit 1
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
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统。" && exit 1
fi

[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install curl)
[[ $(type -P kmod) ]] || $yumapt install kmod
vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
sys(){
[ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
[ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
[ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return;}
op=`sys`
version=`uname -r | awk -F "-" '{print $1}'`
main=`uname  -r | awk -F . '{print $1 }'`
minor=`uname -r | awk -F . '{print $2}'`
uname -m | grep -q -E -i "aarch" && cpu=ARM64 || cpu=AMD64
vi=`systemd-detect-virt`
if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="openvz版bbr-plus"
else
bbr="暂不支持显示"
fi
v46=`curl -s api64.ipify.org -k`
if [[ $v46 =~ '.' ]]; then
ip="$v46（IPV4优先）" 
else
ip="$v46（IPV6优先）"
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

root(){
bash <(curl -L -s https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/root.sh)
back
}

gengxin() {
  echo -e "当前版本为 [ ${esV} ]，开始检测最新版本..."
  es_new_V=$(wget -qO- "https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/esinstall.sh" | grep 'esV="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1)
  [[ -z ${es_new_V} ]] && echo -e "${Error} 检测最新版本失败 !" && start_menu
  if [ ${es_new_V} != ${esV} ]; then
    echo -e "发现新版本[ ${es_new_V} ]，是否更新？[Y/n]"
    read -p "(默认: y):" yn
    [[ -z "${yn}" ]] && yn="y"
    if [[ ${yn} == [Yy] ]]; then
      wget -N "https://${github}/esinstall.sh" && chmod +x esinstall.sh && ./esinstall.sh
      echo -e "脚本已更新为最新版本[ ${es_new_V} ] !"
    else
      echo && echo "	已取消..." && echo
    fi
  else
    echo -e "当前已是最新版本[ ${es_new_V} ] !"
    sleep 2s && ./esinstall.sh
  fi
}

v4v6(){
v46=`curl -s api64.ipify.org -k`
[[ $v46 =~ '.' ]] && green "当前VPS本地为IPV4优先：$v46" || green "当前VPS本地为IPV6优先：$v46"
ab="1.设置IPV4优先\n2.设置IPV6优先\n3.恢复系统默认优先\n0.返回上一层\n 请选择："
readp "$ab" cd
case "$cd" in 
1 )
[[ -e /etc/gai.conf ]] && grep -qE '^ *precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
sed -i '/^label 2002::\/16   2/d' /etc/gai.conf
v46=`curl -s api64.ipify.org -k`
[[ $v46 =~ '.' ]] && green "当前VPS本地为IPV4优先：$v46" || green "当前VPS本地为IPV6优先：$v46"
back;;
2 )
[[ -e /etc/gai.conf ]] && grep -qE '^ *label 2002::/16   2' /etc/gai.conf || echo 'label 2002::/16   2' >> /etc/gai.conf
sed -i '/^precedence ::ffff:0:0\/96  100/d' /etc/gai.conf
v46=`curl -s api64.ipify.org -k`
[[ $v46 =~ '.' ]] && green "当前VPS本地为IPV4优先：$v46" || green "当前VPS本地为IPV6优先：$v46"
back;;
3 )
sed -i '/^precedence ::ffff:0:0\/96  100/d;/^label 2002::\/16   2/d' /etc/gai.conf
v46=`curl -s api64.ipify.org -k`
[[ $v46 =~ '.' ]] && green "当前VPS本地为IPV4优先：$v46" || green "当前VPS本地为IPV6优先：$v46"
back;;
0 ) 
bash <(curl -sSL https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/esinstall.sh)
esac
}

bbrInstall(){
wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

opport(){
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
green "关闭VPS防火墙、开放端口规则执行完毕"
back
}

xrayInstall() {
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
}

get_char(){
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}


back(){
white "------------------------------------------------------------------------------------------------"
white " 回主菜单，请按任意键"
white " 退出脚本，请按Ctrl+C"
get_char && bash <(curl -sSL https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/esinstall.sh)
}

TGInstall() {
bash <(curl -sSL "https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/mtp.sh")
}

tuic() {
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/tuic/tuic.sh && bash tuic.sh
}

naiveproxy() {
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/naiveproxy/naiveproxy.sh && bash naiveproxy.sh
}

hysteria() {
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/hysteria/hysteria.sh && bash hysteria.sh
}

BT() {
if [[ -f /etc/redhat-release ]]; then
yum install -y wget && wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh && bash install.sh aapanel
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh && sudo bash install.sh aapanel
elif cat /etc/issue | grep -q -E -i "debian"; then
wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh && bash install.sh aapanel
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
yum install -y wget && wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh && bash install.sh aapanel
else 
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统。" && exit 1
fi
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


start_menu(){
 clear
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1.更新脚本" 
green " 2.hysteria"
green " 3.naiveproxy"
green " 4.tuic"
green " 5.安装nginx有宝塔的不用安装"
green " 6.ssl证书(请先确保端口打开)"
green " 7.安装x-ui"
green " 8.安装x-ui并替换文件"
green " 9.转发救机"
green " 10.安装bbr"
green " 11.一键Xray"
green " 12.安装哪吒探针"
green " 13.电报代理"
green " 14.宝塔国际版"
green " 15.关闭VPS防火墙、开放端口规则"
green " 16.VPS一键root脚本、更改root密码"
green " 17.更改VPS本地IP优先级"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "一键安装管理脚本 ${Red_font_prefix}[v${esV}]${Font_color_suffix}"
white " 再次进入输入 es"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white " VPS系统信息如下："
white " 操作系统      : $(blue "$op")" 
white " 内核版本      : $(blue "$version")" 
white " CPU架构       : $(blue "$cpu")" 
white " 虚拟化类型    : $(blue "$vi")" 
white " TCP加速算法   : $(blue "$bbr")" 
white " 本地IP优先级  : $(blue "$ip")"       
echo
readp "请输入数字:" Input
case "$Input" in  
 1 ) gengxin;;
 2 ) hysteria;;
 3 ) naiveproxy;;
 4 ) tuic;;
 5 ) nginx;;
 6 ) acme;;
 7 ) x-ui;;
 8 ) x-uimogai;; 
 9 ) zhuanfa;;
 10 ) bbrInstall;;
 11 ) xrayInstall;;
 12 ) nezhamianban;;
 13 ) TGInstall;;
 14 ) BT;;
 15 ) opport;;
 16 ) root;;
 17 ) v4v6;;
 * ) exit 
esac
}
if [ $# == 0 ]; then
start_menu
fi
