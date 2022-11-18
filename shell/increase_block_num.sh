source .env
for _ in `seq 1 $2`
do
cast send $1 "state(uint256)()" 0 --private-key $DEPLOYER_KEY
done
