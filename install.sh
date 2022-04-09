#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#开始菜单
start_menu() {
  clear
  echo && echo -e " 一键安装管理脚本
————————————————————————————————————————————————————————————————  
 1.同步上海时间
 2.关闭ubuntu防火墙
 3.关闭centos防火墙
 4.安装nginx有宝塔的不用安装
 5.ssl证书(请先确保端口打开)
 6.安装x-ui
 7.安装x-ui并替换文件
 8.转发救机
 9.安装bbr
 10.一键Xray
 11.安装哪吒探针
 0.退出
————————————————————————————————————————————————————————————————" &&


  read -p " 请输入数字 :" num
  case "$num" in
  1)
    shanghai
    ;;
  2)
    ubuntu
    ;;
  3)
    centos
    ;;
  4)
    nginx
    ;;    
  5)
    ssl
    ;;
  6)
    x-ui
    ;;
  7)
    x-uimogai
    ;;
  8)
    zhuanfa
    ;;
  9)
    bbrInstall
    ;;
  10)
    xrayInstall
    ;;    
  11)
    nezhaianban
    ;;   
  
  0)
    exit 1
    ;;
  *)
    clear
    echo -e "${Error}:请输入正确数字 [0～7]"
    sleep 5s
    start_menu
    ;;
  esac
}

#安装nginx
nginx() {
yum update -y || apt update -y
yum install nginx curl wget -y || apt install nginx curl wget -y
systemctl start nginx.service
systemctl enable nginx.service
start_menu
}

#安装哪吒面板
nezhamianban() {
curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh  -o nezha.sh && chmod +x nezha.sh
sudo ./nezha.sh
start_menu
}

#转发救机
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
start_menu
}

#证书
ssl() {
apt update -y || yum update -y 
apt install -y curl || yum install -y curl
apt install -y socat || yum install -y socat
curl https://get.acme.sh | sh
read -p "请输入E-mail: " email
read -p "请输入域名: " domain
~/.acme.sh/acme.sh --register-account -m $email
~/.acme.sh/acme.sh  --issue -d $domain   --standalone
~/.acme.sh/acme.sh --installcert -d $domain --key-file /root/private.key --fullchain-file /root/cert.crt
start_menu
}

#安装x-ui
x-uimogai() {
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
rm -f /usr/local/x-ui/bin/xray-linux-amd64
wget --no-check-certificate -O /usr/local/x-ui/bin/xray-linux-amd64 "https://cdn.jsdelivr.net/gh/Jason6111/ExpressSetup@main/xray-linux-amd64"
sudo chmod 755 /usr/local/x-ui/bin/xray-linux-amd64
systemctl restart x-ui
start_menu
}
#安装x-ui
x-ui() {
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
start_menu
}

#安装809
809() {
bash <(curl -s https://raw.githubusercontent.com/shoujiyanxishe/shjb/main/lt809ml/sub )
start_menu
}

#关闭ubutn防火墙
ubuntu() {
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
iptables-save
apt-get install iptables-persistent
netfilter-persistent save
netfilter-persistent reload
start_menu
}

#安装BBR
bbrInstall() {
wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
start_menu
}

#一键Xray
xrayInstall() {
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
start_menu
}

#关闭centos防火墙
centos() {
systemctl stop firewalld.service
systemctl disable firewalld.service
start_menu
}

#同步时间
shanghai() {
timedatectl set-timezone Asia/Shanghai
start_menu
}
start_menu
