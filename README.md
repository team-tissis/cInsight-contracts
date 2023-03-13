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

その次に，.env ファイルにコンソールに出力された(0)番目の private key を記述．(.env.sample を参照)

```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEPLOYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

Finally,

```bash
$ forge script script/cInsightScript.s.sol:cInsightScript --fork-url http://localhost:8545 --broadcast
```
