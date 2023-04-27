source .env
# specify the address of Bonfire as the first argument
cast send $1 "monthInit()()" 1  --private-key $DEPLOYER_KEY
