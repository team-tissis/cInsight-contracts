source .env
sh increase_block_num.sh $1 241
cast send $1 "queue(uin256)()" 1  --private-key $DEPROYER_KEY
