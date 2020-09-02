#!/bin/bash
CRONTAB=/etc/cron.d/nodechecker
cat >$CRONTAB <<EOF
*/5 * * * * root bash  /opt/ghpb-bin/nodechecker.sh  > /dev/null 2>&1
EOF

NODENAME="CHANGEME"
PASSWORD="CHANGEME"
BINARY=/opt/ghpb-bin/ghpb
PORT="8545"
IP=`curl -s ifconfig.me`
FUNCTIONING=false
MINING=false
PEERCOUNT=0
BLOCKNUMBER=0
STARTED=false
NODETYPE=""
TIME=`date -u +%Y-%m-%dT%H:%M:%S`
VERSION=`$BINARY version | sed -n 2p |cut -d ' ' -f2`
REQUIRED_PKG="jq"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
if [ "" = "$PKG_OK" ]; then
  echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
  sudo apt-get --yes install $REQUIRED_PKG
fi

FILE=/tmp/blockNumber.log

STARTED=`nc -z 127.0.0.1 $PORT`
STARTED=$?
if [ $STARTED -lt 1 ]; then
	STARTED=true

	HEXPEERCOUNT=`curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params": ["latest"],"id":2}' http://127.0.0.1:$PORT | jq '.result'`
	PEERCOUNT=$((16#`echo ${HEXPEERCOUNT//\"} | cut -c 3-`))
	NODETYPE=`curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params": ["latest"],"id":2}' http://127.0.0.1:$PORT | jq '.result' | jq '.local' |sed 's/"//g'`
	if test -f "$FILE"; then
		hex=`curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"hpb_blockNumber","params": ["latest"],"id":2}' http://127.0.0.1:$PORT | jq '.result'`
		BLOCKNUMBER=$((16#`echo ${hex//\"} | cut -c 3-`))
		if (( $BLOCKNUMBER == `cat /tmp/blockNumber.log` )); then
			FUNCTIONING=false
		else
			FUNCTIONING=true
			echo $BLOCKNUMBER > $FILE
		fi
	else
        	hex=`curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"hpb_blockNumber","params": ["latest"],"id":2}' http://127.0.0.1:$PORT | jq '.result'`
        	BLOCKNUMBER=$((16#`echo ${hex//\"} | cut -c 3-`))
		echo $BLOCKNUMBER > $FILE
	fi
	if [ $FUNCTIONING == true ]; then
		MINING=`curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"hpb_mining","params": ["latest"],"id":2}' http://127.0.0.1:$PORT | jq '.result' |sed 's/"//g'`
		if [ $MINING == "false" ]; then
			FUNCTIONING=false
		fi
	fi
else
	STARTED=false
	FUNTIONING=false
fi

curl -s -XPOST "https://$NODENAME:$PASSWORD@669a7da94fbb453f80a520d28bbb3662.us-central1.gcp.cloud.es.io:9243/my-map-index/_doc/?pipeline=geoip" -H 'Content-Type: application/json' -d '{ "@timestamp": "'$TIME'", "ip": "'$IP'", "name": "'$NODENAME'", "functioning": '$FUNCTIONING', "nodeType": "'$NODETYPE'", "mining": '$MINING', "peers": "'$PEERCOUNT'", "blocknumber": "'$BLOCKNUMBER'", "running": '$STARTED', "version": "'$VERSION'" }'
