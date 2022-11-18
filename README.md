# contracts
the smart contracts codes

# localnet deploy
Please Install foundry
https://book.getfoundry.sh/getting-started/installation

Next, 
```bash
$ forge build
$ anvil
```
その次に，.envファイルにコンソールに出力された(0)番目のprivate keyを記述．
```bash
DEPLOYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

Finally,
```bash
$ forge script script/cInsightScript.s.sol:cInsightScript --fork-url http://localhost:8545 --broadcast
```