# e2e_cli for bgi_client_baas

fork from svn://192.168.31.103:6500/e2e_cli/e2e_cli.two

## 说明

| 文件                 | 说明                       |
| -------------------- | -------------------------- |
| byfn.sh              | 升级脚本                   |
| cmd.sh               | 常用命令                   |
| dc.py                | docker-compose命令简化脚本 |
| generateArtifacts.sh | 新通道文件生成脚本         |
| network_setup.sh     | e2e区块链启动脚本          |
| eyfn.sh              | 增加组织脚本               |

### 升级镜像脚本

| 文件                       | 说明                 |
| -------------------------- | -------------------- |
| byfn.sh                    | 升级启动脚本         |
| fabric-*-bin.tgz           | 对应版本可执行程序   |
| configtx.*.yaml            | 对应版本配置文件     |
| scripts\utils*.sh          | 对应版本脚本函数     |
| scripts\capabilities*.json | 对应版本新增属性     |
| scripts\upgrade_to_v*.sh   | 对应版本升级通道脚本 |

### 新增组织节点

| 文件                 | 说明             |
| -------------------- | ---------------- |
| eyfn.sh              | 增加组织启动脚本 |
| scripts\step1org3.sh | 升级配置         |
| scripts\step2org3.sh | join channel     |
| scripts\step3org3.sh | 升级链码         |
| scripts\testorg3.sh  | 测试org3         |

#### 升级镜像操作

./cmd.sh e2edown # 清空
./cmd.sh e2eup   # 重启1.2.1
./eyfn.sh up     # 新增组织节点

## 环境依赖

1. golang环境
2. fabric-1.2.1镜像

## 发布版本特性
