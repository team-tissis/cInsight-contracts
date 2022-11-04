source .env
sh increase_block_num.sh $1 2 
cast send $1 "castVoteWithReason(uin256,uint8,string)()" 1 1 "I'd like to give favos to more people since more and more entities are joining this DAO." --private-key $DEPROYER_KEY
