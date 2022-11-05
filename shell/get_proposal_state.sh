source .env
cast call $1 "state(uint256)()" 1 --private-key $DEPROYER_KEY
cast call $1 "getEndBlock(uint256)(uint256)" 1 --private-key $DEPROYER_KEY
