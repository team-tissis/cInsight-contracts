source .env

sh shell/increase_block_num.sh $1 2 

sh shell/for_vote.sh $1
sh shell/increase_block_num.sh $1 250

sh shell/queue.sh $1
sh shell/increase_block_num.sh $1 250

sh shell/execute.sh $1
