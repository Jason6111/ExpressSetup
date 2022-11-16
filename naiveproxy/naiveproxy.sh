#!/bin/bash
naygV="22.11.12 V 1.8"
remoteV=`wget -qO- https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/naiveproxy/naiveproxy.sh | sed  -n 2p | cut -d '"' -f 2`
chmod +x /root/naiveproxy.sh
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
if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="openvz版bbr-plus"
else
bbr="暂不支持显示"
fi

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
[[ ! $(type -P qrencode) ]] && ($yumapt update;$yumapt install qrencode)
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

insupdate(){
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
apt update
fi
}
forwardproxy(){
go env -w GO111MODULE=on
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
}
rest(){
if [[ ! -f /root/caddy ]]; then
red "caddy2-naiveproxy构建失败，脚本退出" && exit
fi
chmod +x caddy
mv caddy /usr/bin/
}

inscaddynaive(){
naygvsion=`curl -s "https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/naiveproxy/version"`
green "请选择安装或者更新 naiveproxy 内核方式:"
readp "1. 使用已编译好的 caddy2-naiveproxy 版本，当前已编译到最新版本号： $naygvsion （快速安装，回车默认）\n2. 自动编译最新 caddy2-naiveproxy 版本，当前官方最新版本号： $lastvsion （存在编译失败可能）\n请选择：" chcaddynaive
if [ -z "$chcaddynaive" ] || [ $chcaddynaive == "1" ]; then
insupdate
cd /root
wget -N --no-check-certificate https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/naiveproxy/caddy2-naive-linux-${cpu}.tar.gz
wget -qN --no-check-certificate https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/naiveproxy/version
tar zxvf caddy2-naive-linux-${cpu}.tar.gz
rm caddy2-naive-linux-${cpu}.tar.gz -f
cd
rest
elif [ $chcaddynaive == "2" ]; then
if [[ $release = Centos ]] && [[ ${vsid} =~ 8 ]]; then
green "Centos 8 系统建议使用编译好的caddy2-naiveproxy版本" && inscaddynaive
fi
insupdate
cd /root
if [[ $release = Centos ]]; then 
rpm --import https://mirror.go-repo.io/centos/RPM-GPG-KEY-GO-REPO
curl -s https://mirror.go-repo.io/centos/go-repo.repo | tee /etc/yum.repos.d/go-repo.repo
yum install golang && forwardproxy
else
apt install software-properties-common -y
add-apt-repository ppa:longsleep/golang-backports 
apt update 
apt install golang-go && forwardproxy
fi
cd
rest
lastvsion=v`curl -Ls https://data.jsdelivr.com/v1/package/gh/klzgrad/naiveproxy | sed -n 4p | tr -d ',"' | awk '{print $1}'`
echo $lastvsion > /root/version
else 
red "输入错误，请重新选择" && inscaddynaive
fi
version(){
if [[ ! -d /etc/caddy/ ]]; then
mkdir /etc/caddy >/dev/null 2>&1
fi
mv version /etc/caddy/
}
version
}

inscertificate(){
green "naiveproxy协议证书申请方式选择如下:"
readp "1. acme一键申请证书脚本（支持常规80端口模式与dns api模式），已用此脚本申请的证书则自动识别（回车默认）\n2. 自定义证书路径（非/root/ca路径）\n请选择：" certificate
if [ -z "${certificate}" ] || [ $certificate == "1" ]; then
if [[ -f /root/ca/cert.crt && -f /root/ca/private.key ]] && [[ -s /root/ca/cert.crt && -s /root/ca/private.key ]] && [[ -f /root/ca/ca.log ]]; then
blue "经检测，之前已使用此acme脚本申请过证书"
readp "1. 直接使用原来的证书（回车默认）\n2. 删除原来的证书，重新申请证书\n请选择：" certacme
if [ -z "${certacme}" ] || [ $certacme == "1" ]; then
ym=$(cat /root/ca/ca.log)
blue "检测到的域名：$ym ，已直接引用\n"
elif [ $certacme == "2" ]; then
curl https://get.acme.sh | sh
bash /root/.acme.sh/acme.sh --uninstall
rm -rf /root/ca
rm -rf ~/.acme.sh acme.sh
sed -i '/--cron/d' /etc/crontab
[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh卸载完毕" || red "acme.sh卸载失败"
sleep 2
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
ym=$(cat /root/ca/ca.log)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/yca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
else
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh && bash acme.sh
ym=$(cat /root/ca/ca.log)
if [[ ! -f /root/ca/cert.crt && ! -f /root/ca/private.key ]] && [[ ! -s /root/ca/cert.crt && ! -s /root/ca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
certificatec='/root/ca/cert.crt'
certificatep='/root/ca/private.key'
elif [ $certificate == "2" ]; then
readp "请输入已放置好的公钥文件crt的路径（/a/b/……/cert.crt）：" cerroad
blue "公钥文件crt的路径：$cerroad "
readp "请输入已放置好的密钥文件key的路径（/a/b/……/private.key）：" keyroad
blue "密钥文件key的路径：$keyroad "
certificatec=$cerroad
certificatep=$keyroad
readp "请输入已解析好的域名:" ym
blue "已解析好的域名：$ym "
else 
red "输入错误，请重新选择" && inscertificate
fi
}
insport(){
readp "\n设置naiveproxy端口[1-65535]（回车跳过为2000-65535之间的随机端口）：" port
if [[ -z $port ]]; then
port=$(shuf -i 2000-65535 -n 1)
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义naiveproxy端口:" port
done
else
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义naiveproxy端口:" port
done
fi
blue "已确认端口：$port\n"
}
inswym(){
readp "设置伪装域名（回车默认）：" wym
if [[ -z ${wym} ]]; then
wym="www.xxxxx520.com"
fi
blue "已确认伪装域名：${wym}\n"
}
insuser(){
readp "设置naiveproxy用户名（回车跳过为随机6位字符）：" user
if [[ -z ${user} ]]; then
user=`date +%s%N |md5sum | cut -c 1-6`
fi
blue "已确认用户名：${user}\n"
}
inspswd(){
readp "设置naiveproxy密码（回车跳过为随机10位字符）：" pswd
if [[ -z ${pswd} ]]; then
pswd=`date +%s%N |md5sum | cut -c 1-10`
fi
blue "已确认密码：${pswd}\n"
}
insconfig(){
readp "设置caddy2-naiveproxy监听端口[1-65535]（回车跳过为2000-65535之间的随机端口）：" caddyport
if [[ -z $caddyport ]]; then
caddyport=$(shuf -i 2000-65535 -n 1)
if [[ $caddyport == $port ]]; then
yellow "\n端口被占用，请重新输入端口" && readp "自定义caddy2-naiveproxy监听端口:" caddyport
fi
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$caddyport") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$caddyport") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义caddy2-naiveproxy监听端口:" caddyport
done
else
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$caddyport") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$caddyport") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义caddy2-naiveproxy监听端口:" caddyport
done
fi
blue "已确认端口：$caddyport\n"
green "设置naiveproxy的配置文件、服务进程……\n"
mkdir /root/naive >/dev/null 2>&1
mkdir /etc/caddy >/dev/null 2>&1
cat << EOF >/etc/caddy/Caddyfile
{
http_port $caddyport
}
:$port, $ym:$port {
tls ${certificatec} ${certificatep} 
route {
 forward_proxy {
   basic_auth ${user} ${pswd}
   hide_ip
   hide_via
   probe_resistance
  }
 reverse_proxy  $wym  {
   header_up  Host  {upstream_hostport}
   header_up  X-Forwarded-Host  {host}
  }
}
}
EOF
cat <<EOF > /root/naive/v2rayn.json
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://${user}:${pswd}@${ym}:$port"
}
EOF
cat << EOF >/etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target
[Service]
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
PrivateTmp=false
NoNewPrivileges=yes
ProtectHome=false
ProtectSystem=false
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable caddy
systemctl start caddy
}
stclre(){
if [[ ! -f '/etc/caddy/Caddyfile' ]]; then
green "未正常安装naiveproxy" && exit
fi
green "naiveproxy服务执行以下操作"
readp "1. 重启\n2. 关闭\n3. 启动\n请选择：" action
if [[ $action == "1" ]]; then
systemctl restart caddy
green "naiveproxy服务重启\n"
elif [[ $action == "2" ]]; then
systemctl stop caddy
systemctl disable caddy
green "naiveproxy服务关闭\n"
elif [[ $action == "3" ]]; then
systemctl enable caddy
systemctl start caddy
green "naiveproxy服务开启\n"
else
red "输入错误,请重新选择" && stclre
fi
}
changeserv(){
if [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && ! -f '/etc/caddy/Caddyfile' ]]; then
red "未正常安装naiveproxy" && exit
fi
green "naiveproxy配置变更选择如下:"
readp "1. 添加或删除多端口复用(每执行一次添加一个端口)\n2. 变更主端口\n3. 变更用户名\n4. 变更密码\n5. 重新申请证书或变更证书路径\n6. 返回上层\n请选择：" choose
if [ $choose == "1" ];then
duoport
elif [ $choose == "2" ];then
changeport
elif [ $choose == "3" ];then
changeuser
elif [ $choose == "4" ];then
changepswd
elif [ $choose == "5" ];then
inscertificate
oldcer=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 5p | awk '{print $2}'`
oldkey=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 5p | awk '{print $3}'`
sed -i "s#$oldcer#${certificatec}#g" /etc/caddy/Caddyfile
sed -i "s#$oldkey#${certificatep}#g" /etc/caddy/Caddyfile
sed -i "s#$oldcer#${certificatec}#g" /etc/caddy/reCaddyfile
sed -i "s#$oldkey#${certificatep}#g" /etc/caddy/reCaddyfile
oldym=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 4p | awk '{print $2}'| awk -F":" '{print $1}'`
sed -i "s/$oldym/${ym}/g" /etc/caddy/Caddyfile /etc/caddy/reCaddyfile /root/naive/URL.txt /root/naive/v2rayn.json
sussnaiveproxy
elif [ $choose == "6" ];then
na
else 
red "请重新选择" && changeserv
fi
}
duoport(){
naiveports=`cat /etc/caddy/Caddyfile 2>/dev/null | awk '{print $1}' | grep : | tr -d ',:'`
green "\n当前naiveproxy代理正在使用的端口："
blue "$naiveports"
readp "\n1. 添加多端口复用\n2. 恢复仅一个主端口\n3. 返回上层\n请选择：" choose
if [ $choose == "1" ]; then
oldport1=`cat /etc/caddy/reCaddyfile 2>/dev/null | sed -n 4p | awk '{print $1}'| tr -d ',:'`
insport
sed -i "s/$oldport1/$port/g" /etc/caddy/reCaddyfile
cat /etc/caddy/reCaddyfile 2>/dev/null | tail -15 >> /etc/caddy/Caddyfile
sussnaiveproxy
elif [ $choose == "2" ]; then
sed -i '19,$d' /etc/caddy/Caddyfile 2>/dev/null
sussnaiveproxy
elif [ $choose == "3" ]; then
changeserv
else 
red "请重新选择" && duoport
fi
}
changeuser(){
olduserc=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 8p | awk '{print $2}'`
echo
blue "当前正在使用的用户名：$olduserc"
echo
insuser
sed -i "s/$olduserc/${user}/g" /etc/caddy/Caddyfile /etc/caddy/reCaddyfile /root/naive/URL.txt /root/naive/v2rayn.json
sussnaiveproxy
}
changepswd(){
oldpswdc=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 8p | awk '{print $3}'`
echo
blue "当前正在使用的密码：$oldpswdc"
echo
inspswd
sed -i "s/$oldpswdc/${pswd}/g" /etc/caddy/Caddyfile /etc/caddy/reCaddyfile /root/naive/URL.txt /root/naive/v2rayn.json
sussnaiveproxy
}
changeport(){
oldport1=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 4p | awk '{print $1}'| tr -d ',:'`
echo
blue "当前正在使用的主端口：$oldport1"
echo
insport
sed -i "s/$oldport1/$port/g" /etc/caddy/Caddyfile /root/naive/v2rayn.json /root/naive/URL.txt
sussnaiveproxy
}

acme(){
bash <(curl -L -s https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/acme.sh)
}
cfwarp(){
wget -N --no-check-certificate https://gitlab.com/rwkgyg/cfwarp/raw/main/CFwarp.sh && bash CFwarp.sh
}
bbr(){
bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
}

naiveproxystatus(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
[[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]] && wgcf=$(green "未启用") || wgcf=$(green "启用中")
naiveports=`cat /etc/caddy/Caddyfile 2>/dev/null | awk '{print $1}' | grep : | tr -d ',:' | tr '\n' ' '`
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
status=$(white "naiveproxy状态：\c";green "运行中    \c";white "可代理端口：\c";green "$naiveports";white "WARP状态：      \c";eval echo \$wgcf)
elif [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
status=$(white "naiveproxy状态：\c";yellow "未启动,可尝试选择4，开启或者重启，依旧如此建议卸载重装naiveproxy";white "WARP状态：      \c";eval echo \$wgcf)
else
status=$(white "naiveproxy状态：\c";red "未安装";white "WARP状态：      \c";eval echo \$wgcf)
fi
}

upnayg(){
if [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && ! -f '/etc/caddy/Caddyfile' ]]; then
red "未正常安装naiveproxy" && exit
fi
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/naiveproxy/naiveproxy.sh
chmod +x /root/naiveproxy.sh 
ln -sf /root/naiveproxy.sh /usr/bin/na
green "naiveproxy安装脚本升级成功" && na
}

upnaive(){
if [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && ! -f '/etc/caddy/Caddyfile' ]]; then
red "未正常安装naiveproxy" && exit
fi
green "\n升级naiveproxy内核版本\n"
inscaddynaive
systemctl restart caddy
green "naiveproxy内核版本升级成功" && na
}

unins(){
systemctl stop caddy >/dev/null 2>&1
systemctl disable caddy >/dev/null 2>&1
rm -f /etc/systemd/system/caddy.service
rm -rf /usr/bin/caddy /etc/caddy /root/naive /root/naiveproxy.sh /usr/bin/na
green "naiveproxy卸载完成！"
}

sussnaiveproxy(){
systemctl restart caddy
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
green "naiveproxy服务启动成功" && naiveproxyshare
else
red "naiveproxy服务启动失败，请运行systemctl status caddy查看服务状态并反馈，脚本退出" && exit
fi
}

naiveproxyshare(){
if [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && ! -f '/etc/caddy/Caddyfile' ]]; then
red "未正常安装naiveproxy" && exit
fi
red "======================================================================================"
naiveports=`cat /etc/caddy/Caddyfile 2>/dev/null | awk '{print $1}' | grep : | tr -d ',:'`
green "\n当前naiveproxy代理正在使用的端口：" && sleep 2
blue "$naiveports\n"
green "当前v2rayn客户端配置文件v2rayn.json内容如下，保存到 /root/naive/v2rayn.json\n"
yellow "$(cat /root/naive/v2rayn.json)\n" && sleep 2
green "当前naiveproxy节点分享链接如下，保存到 /root/naive/URL.txt"
yellow "$(cat /root/naive/URL.txt)\n" && sleep 2
green "当前naiveproxy节点二维码分享链接如下(SagerNet / Matsuri)"
qrencode -o - -t ANSIUTF8 "$(cat /root/naive/URL.txt)"
}

insna(){
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
green "已安装naiveproxy，重装请先执行卸载功能" && exit
fi
rm -f /etc/systemd/system/caddy.service
rm -rf /usr/bin/caddy /etc/caddy /root/naive /usr/bin/na
inscaddynaive ; inscertificate ; insport ; inswym ; insuser ; inspswd ; insconfig
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
green "naiveproxy服务启动成功"
chmod +x /root/naiveproxy.sh 
ln -sf /root/naiveproxy.sh /usr/bin/na
cp -f /etc/caddy/Caddyfile /etc/caddy/reCaddyfile >/dev/null 2>&1
if [[ ! $vi =~ lxc|openvz ]]; then
sysctl -w net.core.rmem_max=8000000
sysctl -p
fi
else
red "naiveproxy服务启动失败，请运行systemctl status caddy查看服务状态并反馈，脚本退出" && exit
fi
red "======================================================================================"
url="naive+https://${user}:${pswd}@${ym}:$port?padding=true#Naive-${ym}"
echo ${url} > /root/naive/URL.txt
green "\nnaiveproxy代理服务安装完成，生成脚本的快捷方式为 na" && sleep 3
blue "\nv2rayn客户端配置文件v2rayn.json保存到 /root/naive/v2rayn.json\n"
yellow "$(cat /root/naive/v2rayn.json)\n"
blue "分享链接保存到 /root/naive/URL.txt" && sleep 3
yellow "${url}\n"
green "二维码分享链接如下(SagerNet / Matsuri)" && sleep 2
qrencode -o - -t ANSIUTF8 "$(cat /root/naive/URL.txt)"
}
start_menu(){
naiveproxystatus
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "  1. 安装naiveproxy（必选）" 
green "  2. 卸载naiveproxy"
white "----------------------------------------------------------------------------------"
green "  3. 变更配置（多端口复用、主端口、用户名、密码、证书）" 
green "  4. 关闭、开启、重启naiveproxy"   
green "  5. 更新naiveproxy安装脚本"
green "  6. 更新naiveproxy内核版本"
white "----------------------------------------------------------------------------------"
green "  7. 显示当前naiveproxy分享链接、V2rayN配置文件、二维码"
green "  8. ACME证书管理菜单"
green "  9. 安装WARP（可选）"
green " 10. 安装BBR+FQ加速（可选）"
green "  0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
if [ "${naygV}" = "${remoteV}" ]; then
echo -e "当前 naiveproxy 安装脚本版本号：${bblue}${naygV}${plain} ，已是最新版本\n"
else
echo -e "当前 naiveproxy 安装脚本版本号：${bblue}${naygV}${plain}"
echo -e "检测到最新 naiveproxy 安装脚本版本号：${yellow}${remoteV}${plain} ，可选择5进行更新\n"
fi
if [ "$ygvsion" = "$lastvsion" ]; then
echo -e "当前 naiveproxy 已安装内核版本号：${bblue}${ygvsion}${plain} ，已是官方最新版本"
else
echo -e "当前 naiveproxy 已安装内核版本号：${bblue}${ygvsion}${plain}"
echo -e "检测到最新 naiveproxy 内核版本号：${yellow}${lastvsion}${plain} ，可选择6进行更新"
fi
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white "VPS系统信息如下："
white "操作系统：      $(blue "$op")" && white "内核版本：      $(blue "$version")" && white "CPU架构：       $(blue "$cpu")" && white "虚拟化类型：    $(blue "$vi")" && white "TCP加速算法：   $(blue "$bbr")"
white "$status"
echo
readp "请输入数字:" Input
case "$Input" in     
 1 ) insna;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) stclre;;
 5 ) upnayg;; 
 6 ) upnaive;;
 7 ) naiveproxyshare;;
 8 ) acme;;
 9 ) cfwarp;;
 10 ) bbr;;
 * ) exit 
esac
}
if [ $# == 0 ]; then
start
lastvsion=v`curl -Ls https://data.jsdelivr.com/v1/package/gh/klzgrad/naiveproxy | sed -n 4p | tr -d ',"' | awk '{print $1}'`
ygvsion=`cat /etc/caddy/version 2>/dev/null`
start_menu
fi
