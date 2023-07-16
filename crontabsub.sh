#定时抓取sub
#!/bin/bash

# 抓取域名内容并解码
domain1_content=$(curl -s https://www.example1.com | base64 -d)
domain2_content=$(curl -s https://www.example2.com | base64 -d)
domain3_content=$(curl -s https://www.example3.com | base64 -d)

# 合并内容为一个字符串
combined_content="$domain1_content$domain2_content$domain3_content"

# 将合并后的内容进行64base编码
encoded_content=$(echo -n "$combined_content" | base64)

# 打印合并后的64base编码内容
echo "$encoded_content" > #自己要保存的路径/名字
