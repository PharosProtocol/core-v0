utilAddr=$(forge create src/LibUtil.sol:Utils --keystore $1 -c 5 -r $GOERLI_RPC_URL)
utilAddr=$(echo $utilAddr |  egrep -o '0x[a-f0-9A-F]{40} ' | tail -n1)


accountAddr=$(forge create --keystore $1 -c 5 -r $GOERLI_RPC_URL --libraries src/LibUtil.sol:Utils:$utilAddr src/modules/account/implementations/ERC20Account.sol:ERC20Account --constructor-args 0x0000000000000000000000000000000000000000)
accountAddr=$(echo $accountAddr |  egrep -o '0x[a-f0-9A-F]{40} ' | tail -n1)

echo $utilAddr
echo $accountAddr

