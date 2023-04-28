source .env
# specify the address of ChainInsightGovernanceProxy as the first argument
# 0x9A676e781A523b5d0C0e43731313A708CB607508
cast send $1 "execute(uint256)()" 1  --private-key $DEPLOYER_KEY
