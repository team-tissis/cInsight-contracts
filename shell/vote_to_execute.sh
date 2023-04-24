source .env

sh shell/increase_block_num.sh $1 2 

sh shell/for_vote.sh $1
sh shell/increase_block_num.sh $1 150

sh shell/queue.sh $1
sh shell/increase_block_num.sh $1 30

sh shell/execute.sh $1
