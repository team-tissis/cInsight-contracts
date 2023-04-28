source .env
# specify the address of ChainInsightGovernanceProxy as the first argument
# 0x9A676e781A523b5d0C0e43731313A708CB607508
sh shell/increase_block_num.sh $1 2 

sh shell/for_vote.sh $1
sh shell/increase_block_num.sh $1 150

sh shell/queue.sh $1
sh shell/increase_block_num.sh $1 30

sh shell/execute.sh $1
