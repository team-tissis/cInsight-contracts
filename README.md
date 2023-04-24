# cInsightContracts

- ChainInsight に使用されているスマートコントラクトを管理するレポジトリです。

# Localnet deploy

- 以下の URL を参考に、foundry をインストールしてください:

  https://book.getfoundry.sh/getting-started/installation

- インストール後、以下のコードを実行すると、anvil ネットワークを展開できます。

  ```bash
  $ forge build
  $ anvil
  ```

- 続いて、.env.sample を参考に、.env ファイルにコンソールに出力された(0)番目のプライベートキーを PRIVATE_KEY と DEPLOYER_KEY に記述してください:

  - これによって、アプリ立ち上げ時のユーザーとデプロイヤーが同一視されます。

  ```bash
  PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  DEPLOYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  ```

- 最後に、以下のコードを実行して、スマートコントラクトをデプロイしてください:
  ```bash
  $ forge script script/cInsightDeploy.s.sol --fork-url http://localhost:8545 --broadcast
  $ forge script script/cInsightScript.s.sol --fork-url http://localhost:8545 --broadcast
  ```

# Script for governance

- 以下のようにしてシェルスクリプトを実行することで、投票から実行までをデモンストレーションすることができます。
  ```
  sh shell/vote_to_execute.sh <Address of ChainInsightGovernanceProxy>
  ```
