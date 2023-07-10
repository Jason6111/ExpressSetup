#!/bin/bash
case "$(uname -m)" in
	x86_64 | x64 | amd64 )
	cpu=amd64
	;;
	i386 | i686 )
        cpu=386
	;;
	armv8 | armv8l | arm64 | aarch64 )
        cpu=arm64
	;;
	armv7l )
        cpu=arm
	;;
	* )
	echo "The current architecture is $(uname -m), which is not supported yet"
	exit
	;;
esac
( [ ! -f /tmp/pkgupdate ] && $(type -P yum || type -P apt) update && touch /tmp/pkgupdate ) 2> /dev/null >/dev/null
$(type -P yum || type -P apt) install -y qrencode 2> /dev/null | grep -v "already installed" >/dev/null
rmrf(){
rm -rf wgcf-account.toml wgcf-profile.conf warpgo.conf sbwarp.json warp-go warp.conf wgcf warp-api-wg.txt warpapi
}
note(){
echo "相关说明:"
echo -e "1.要查看warp帐户状态，请参阅 website: https://www.cloudflare.com/cdn-cgi/trace"
echo -e "	warp=on表示普通免费帐户，"
echo -e "	warp=plus表示warp+或团队团队帐户，"
echo -e "	warp=off表示非warp网络\n"
echo -e "2. 此配置与当前注册平台无任何关联，根据实际使用平台的本地网络就近原则来判定warp的IP地区\n"
echo -e "3. 此配置中相关参数可应用于Wireguard客户端、Xray协议的Wireguard-warp出站配置等各类平台\n"
echo -e "4. 此配置中Endpoint的IP端口可替换为实际使用平台的本地网络测试warp优选后的IP端口\n"
echo -e "5. 此配置中PrivateKey、Address的V6地址、reserved(可选)，三个参数相互绑定关联\n"
#echo "当前Sing-box出站配置文件如下" && sleep 1
#echo "$(cat /usr/local/bin/sbwarp.json | python3 -mjson.tool)"
}
acwarpapi(){
echo "下载warp-api注册程序..."
curl -L -o warpapi -# --retry 2 https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/WARP-Wireguard-Register/cpu1/$cpu
chmod +x warpapi
output=$(./warpapi)
if ./warpapi 2>&1 | grep -q "connection refused"; then
echo "申请warp api普通账户失败，请尝试使用warp-go方式进行注册" && exit
fi
private_key=$(echo "$output" | awk -F ': ' '/private_key/{print $2}')
v6=$(echo "$output" | awk -F ': ' '/v6/{print $2}')
res=$(echo "$output" | awk -F ': ' '/reserved/{print $2}' | tr -d '[:space:]')
cat > warp-api-wg.txt <<EOF
[Interface]
PrivateKey = $private_key
Address = 172.16.0.2/32, $v6/128
DNS = 1.1.1.1
MTU = 1280
[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 162.159.193.10:2408
EOF
clear
echo
echo "Warp帐户申请成功" && sleep 3
echo
echo "reserved值：$res" && sleep 2
echo
echo "warp-wireguard（api）配置信息如下" && sleep 2
cat warp-api-wg.txt
echo
sleep 2
qrencode -t ansiutf8 < warp-api-wg.txt 2>/dev/null
echo
note
rmrf
}
wgcfreg(){
echo "下载warp wgcf注册程序..."
curl -L -o wgcf -# --retry 2 https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/WARP-Wireguard-Register/wgcf/wgcf_2.2.17_$cpu
chmod +x wgcf
echo | ./wgcf register 2> /dev/null
if echo | ./wgcf register 2>&1 | grep -q "connection refused"; then
echo "申请warp-wgcf普通账户失败，请尝试使用warp-go注册" && exit
fi
until [[ -e wgcf-account.toml ]]
do
echo "申请warp wgcf普通账户，请稍候" && sleep 1
echo | ./wgcf register
done
echo | ./wgcf generate
sed -i "s/engage.cloudflareclient.com:2408/162.159.193.10:2408/g" wgcf-profile.conf
}
wgcfup(){
if [[ ! -e wgcf-account.toml ]]; then
wgcfreg
fi
read -p "Copy license key (26 characters):" ID
if [[ -z $ID ]]; then
echo "Nothing entered" && exit
fi
sed -i "s/license_key.*/license_key = \"$ID\"/g" wgcf-account.toml
echo | ./wgcf update
echo "如果显示400请求，它将自动恢复到WARP普通帐户"
echo | ./wgcf generate
sed -i "s/engage.cloudflareclient.com:2408/162.159.193.10:2408/g" wgcf-profile.conf
}
wgcfteams(){
wgcfreg
echo "Teams Token获取地址: https://web--public--warp-team-api--coia-mfs4.code.run/"
read -p "请输入团队账号Token: " TEAM_TOKEN
WG_API=$(curl -sSL https://wg.cloudflare.now.cc)
PRIVATEKEY=$(expr "$WG_API" | awk 'NR==2 {print $2}')
PUBLICKEY=$(expr "$WG_API" | awk 'NR==1 {print $2}')
INSTALL_ID=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22)
FCM_TOKEN="${INSTALL_ID}:APA91b$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 134)"
ERROR_TIMES=0
while [ "$ERROR_TIMES" -le 3 ]; do
(( ERROR_TIMES++ ))
if [[ "$TEAMS" =~ 'token is expired' ]]; then
read -p "请刷新令牌并再次复制" TEAM_TOKEN
elif [[ "$TEAMS" =~ 'error' ]]; then
read -p "请刷新令牌并再次复制" TEAM_TOKEN
elif [[ "$TEAMS" =~ 'organization' ]]; then
break
fi
TEAMS=$(curl --silent --location --tlsv1.3 --request POST 'https://api.cloudflareclient.com/v0a2158/reg' \
--header 'User-Agent: okhttp/3.12.1' \
--header 'CF-Client-Version: a-6.10-2158' \
--header 'Content-Type: application/json' \
--header "Cf-Access-Jwt-Assertion: ${TEAM_TOKEN}" \
--data '{"key":"'${PUBLICKEY}'","install_id":"'${INSTALL_ID}'","fcm_token":"'${FCM_TOKEN}'","tos":"'$(date +"%Y-%m-%dT%H:%M:%S.%3NZ")'","model":"Linux","serial_number":"'${INSTALL_ID}'","locale":"zh_CN"}')
ADDRESS6=$(expr "$TEAMS" : '.*"v6":[ ]*"\([^"]*\).*')
done
sed -i "s#PrivateKey.*#PrivateKey = $PRIVATEKEY#g;s#Address.*128#Address = $ADDRESS6/128#g" wgcf-profile.conf
}
wgcfshow(){
clear
echo
echo "Warp帐户申请成功" && sleep 2
echo
echo "warp wireguard（wgcf）配置信息如下" && sleep 2
cat wgcf-profile.conf
echo
sleep 2
qrencode -t ansiutf8 < wgcf-profile.conf 2>/dev/null
echo
note
rmrf
}
warpgoac(){
echo "下载warp-go注册程序..."
curl -L -o warp-go -# --retry 2 https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/WARP-Wireguard-Register/warp-go/warp-go_1.0.8_linux_${cpu}
chmod +x warp-go
curl -L -o warp.conf --retry 2 https://proxy.freecdn.ml?url=https://api.zeroteam.top/warp?format=warp-go
if [[ ! -s warp.conf ]]; then
curl -L -o warpapi -# --retry 2 https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/WARP-Wireguard-Register/cpu1/$cpu
chmod +x warpapi
output=$(./warpapi)
private_key=$(echo "$output" | awk -F ': ' '/private_key/{print $2}')
device_id=$(echo "$output" | awk -F ': ' '/device_id/{print $2}')
warp_token=$(echo "$output" | awk -F ': ' '/token/{print $2}')
rm -rf warpapi
cat > warp.conf <<EOF
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name = WARP
MTU  = 1280
[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.193.10:1701
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive = 30
EOF
fi
}
warpgoplus(){
warpgoac
echo "请在移动WARP客户端的WARP+状态下复制按钮许可证密钥或网络共享密钥（26个字符），并随意输入即可获得1G流量WARP+帐户"
read -p "Please enter the upgrade WARP+ key:" ID
if [[ -z $ID ]]; then
echo "未输入任何内容" && exit
fi
if ./warp-go --update --config=warp.conf --license=$ID --device-name=warp+$(date +%s%N |md5sum | cut -c 1-3) 2>&1 | grep -q "connection refused"; then
echo "网络连接正忙，升级失败"
else
./warp-go --update --config=warp.conf --license=$ID --device-name=warp+$(date +%s%N |md5sum | cut -c 1-3)
fi
}
warpgoteams(){
warpgoac
echo "Teams Token获取地址: https://web--public--warp-team-api--coia-mfs4.code.run/"
read -p "Please enter the team account Token:" ID
if ./warp-go --update --config=warp.conf --team-config=$ID --device-name=warp+teams+$(date +%s%N |md5sum | cut -c 1-3) 2>&1 | grep -q "connection refused"; then
echo "网络连接正忙，升级失败"
else
./warp-go --update --config=warp.conf --team-config=$ID --device-name=warp+teams+$(date +%s%N |md5sum | cut -c 1-3)
fi
}
warpgoconfig(){
if ./warp-go --config=warp.conf --export-wireguard=warpgo.conf 2>&1 | grep -q "connection refused"; then
echo "网络连接繁忙，仅生成WARP-IPV4配置" && sleep 1
output=$(cat warp.conf)
private_key=$(sed -n 's/PrivateKey = \(.*\)/\1/p' warp.conf)
cat > warpgo.conf <<EOF
[Interface]
PrivateKey = $private_key
Address = 172.16.0.2/32
DNS = 1.1.1.1
MTU = 1280
[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
Endpoint = 162.159.193.10:2408
EOF
else
./warp-go --config=warp.conf --export-wireguard=warpgo.conf
./warp-go --config=warp.conf --export-singbox=sbwarp.json
fi
sed -i "s/engage.cloudflareclient.com:2408/162.159.193.10:2408/g" warpgo.conf
}
warpgoshow(){
clear
echo
echo "Warp帐户申请成功" && sleep 3
echo
reserved=$(grep -o '"reserved":\[[^]]*\]' sbwarp.json 2> /dev/null)
if [[ -n $reserved ]]; then
echo "reserved：$reserved" && sleep 2
fi
echo
echo "warp-wireguard（warp-go）配置信息如下" && sleep 2
cat warpgo.conf
echo
sleep 2
qrencode -t ansiutf8 < warpgo.conf 2>/dev/null
echo
note
rmrf
}
acwgcf(){
echo
echo "1.warp-wgcf普通帐户"
echo "2.warp-wgcf+帐户"
echo "3.warp-wgcf+teams团队帐户"
echo "0.退出"
read -p "请选择: " menu
if [ "$menu" == "1" ];then
wgcfreg && wgcfshow
elif [ "$menu" == "2" ];then
wgcfup && wgcfshow
elif [ "$menu" == "3" ];then
wgcfteams && wgcfshow
else
exit
fi
}
acwarpgo(){
echo
echo "1.warp-go普通帐户"
echo "2.warp-go+帐户"
echo "3.warp-go+teams团队账户"
echo "0.退出"
read -p "请选择: " menu
if [ "$menu" == "1" ];then
warpgoac && warpgoconfig && warpgoshow
elif [ "$menu" == "2" ];then
warpgoplus && warpgoconfig && warpgoshow
elif [ "$menu" == "3" ];then
warpgoteams && warpgoconfig && warpgoshow
else
exit
fi
}
echo "------------------------------------------------ ------"
echo "注册生成WARP Wireguard配置文件，二维码"
echo "------------------------------------------------ ------"
echo
echo "1. 选择 warp-go  注册warp配置 (支持所有账户升级、显示reserved值)"
echo "2. 选择 wgcf     注册warp配置 (支持所有账户升级)"
echo "3. 选择 warp api 注册warp配置 (支持显示reserved值)"
echo "0. 退出"
read -p "请选择: " menu
if [ "$menu" == "1" ];then
acwarpgo
elif [ "$menu" == "3" ];then
acwarpapi
elif [ "$menu" == "2" ];then
acwgcf
else
exit
fi
