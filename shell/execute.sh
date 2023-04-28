source .env
# specify the address of ChainInsightGovernanceProxy as the first argument
cast send $1 "execute(uint256)()" 1  --private-key $DEPLOYER_KEY
