#!/bin/bash
TOKEN="TELEGA:TOKEN"
ID_CHAT_DB="TELEGA_CHAT_ID"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"
MESSAGE="Scan started from Inferno!!!"
DAT=`date +%d_%m_%y-%H:%M`
curl -X POST --silent --output /dev/null $URL -d chat_id=$ID_CHAT_DB -d text="$MESSAGE"
sudo masscan -p 5601,9200,9300,9201,8200,9202,8090,9210,9210,9203,8000 -iL all_china_ip.txt -oJ output_ban-china-15k_${DAT}.json --open --rate 15000 --randomize-hosts --banners --source-port 60000 &&
OUTPUT=`cat output-15k_${DAT}.json | wc -l`
MESSAGE2="Scan has been finished!!! Output = $OUTPUT"
gzip output-15k_$DAT.json
curl -F document=@"output-15k_$DAT.json.gz" https://api.telegram.org/bot$TOKEN/sendDocument?chat_id=$ID_CHAT_DB
curl -X POST --silent --output /dev/null $URL -d chat_id=$ID_CHAT_DB -d text="$MESSAGE2"
exit 0
