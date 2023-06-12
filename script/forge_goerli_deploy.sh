utilAddr=$(forge create src/LibUtil.sol:Utils --keystore $1 -c 5 -r $GOERLI_RPC_URL)
utilAddr=$(echo $utilAddr |  egrep -o '0x[a-f0-9A-F]{40} ' | tail -n1)

bookkeeperUtilsAddr=$(forge create --keystore $1 -c 5 -r $GOERLI_RPC_URL --libraries src/LibUtil.sol:Utils:$utilAddr src/bookkeeper/LibBookkeeper.sol:LibBookkeeper)
bookkeeperUtilsAddr=$(echo $bookkeeperUtilsAddr |  egrep -o '0x[a-f0-9A-F]{40} ' | tail -n1)

bookkeeperAddr=$(forge create --keystore $1 -c 5 -r $GOERLI_RPC_URL --libraries src/bookkeeper/LibBookkeeper.sol:LibBookkeeper:$bookkeeperUtilsAddr src/bookkeeper/Bookkeeper.sol:Bookkeeper)
bookkeeperAddr=$(echo $bookkeeperAddr |  egrep -o '0x[a-f0-9A-F]{40} ' | tail -n1)

accountAddr=$(forge create --keystore $1 -c 5 -r $GOERLI_RPC_URL --libraries src/LibUtil.sol:Utils:$utilAddr src/modules/account/implementations/SoloAccount.sol:SoloAccount --constructor-args $bookkeeperAddr)
accountAddr=$(echo $accountAddr |  egrep -o '0x[a-f0-9A-F]{40} ' | tail -n1)

echo "libUtilAddr: " $utilAddr
echo "bookkeeperUtilsAddr: " $bookkeeperUtilsAddr
echo "bookkeeperAddr: " $bookkeeperAddr
echo "accountAddr: " $accountAddr