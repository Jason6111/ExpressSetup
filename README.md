# ExpressSetup
国内脚本  
```
wget -N https://cdn.jsdelivr.net/gh/Jason6111/ExpressSetup@main/esinstall.sh && bash esinstall.sh
```
国外脚本  
```
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/esinstall.sh && bash esinstall.sh
```  
一键hysteria
```
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/hysteria/hysteria.sh && bash hysteria.sh
```
一键naiveproxy
```
wget -N https://raw.githubusercontent.com/Jason6111/ExpressSetup/main/naiveproxy/naiveproxy.sh && bash naiveproxy.sh
```


## 哪吒探针配置
git认证
http://你的域名:8008
http://你的域名:8008/oauth2/callback

git账号创建新的登录验证
Client ID
xxxxxxxx
Client secrets
xxxxxxxx  

报警url代码
https://api.telegram.org/botXXXXXX/sendMessage?chat_id=YYYYYY&text=#NEZHA#

报警规则（每隔10秒检测一次）
[{"Type":"offline","Duration":10}]
