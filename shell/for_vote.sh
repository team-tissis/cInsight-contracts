source .env
cast send $1 "castVoteWithReason(uint256,uint8,string)()" 1 1 "I'd like to give favos to more people since more and more entities are joining this DAO." --private-key $DEPLOYER_KEY
