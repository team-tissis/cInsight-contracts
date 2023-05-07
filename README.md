# cInsightContracts

- cInsight DAO に使用されているスマートコントラクトを管理するレポジトリです。

## スマートコントラクト全体構成

<img src="https://user-images.githubusercontent.com/34847784/200167730-a41fe5da-6881-4b02-8164-95ff33bb1cc1.png" width=800px>

## ローカルネットへのデプロイ

- 以下の URL を参考に、foundry をインストールしてください:

  https://book.getfoundry.sh/getting-started/installation

- インストール後、以下のコードを実行すると、anvil ネットワークを展開できます。

  ```bash
  $ forge build
  $ anvil
  ```

- 続いて、.env.sample を参考に、.env ファイルにコンソールに出力された(0)番目のプライベートキーを PRIVATE_KEY と DEPLOYER_KEY に記述してください:

  ```bash
  PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  DEPLOYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  ```

- 最後に、以下のコードを実行して、スマートコントラクトをデプロイしてください:
  ```bash
  $ forge script script/cInsightDeploy.s.sol --fork-url http://localhost:8545 --broadcast
  $ forge script script/cInsightScript.s.sol --fork-url http://localhost:8545 --broadcast
  ```

## シェルスクリプト

- 投票から実行までのデモンストレーション
  ```
  sh shell/vote_to_execute.sh <Address of ChainInsightGovernanceProxy>
  ```
- 月次のグレード更新
  ```
  sh shell/month_init.sh <Address of Bonfire>
  ```
