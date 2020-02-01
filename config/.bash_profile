export ARCHFLAGS="-arch x86_64"
test -f ~/.bashrc && source ~/.bashrc

function start() {
    # Start node
    GREEN=$(printf "\033[0;32m")
    echo "Starting jormungandr..."
    nohup jormungandr --config ~/files/node-config.yaml --genesis-block-hash $GENESIS_BLOCK_HASH >> ~/logs/node.out 2>&1 &
    sleep 1
    get_pid
}

function stop() {
    # Stop node
    echo "$(jcli rest v0 shutdown get -h http://127.0.0.1:${REST_PORT}/api)"
    sleep 3
    get_pid
}

function stats() {
    # Statistics
    echo "$(jcli rest v0 node stats get -h http://127.0.0.1:${REST_PORT}/api)"
}

function bal() {
    # Wallet balance
    if [[ ! -f ~/files/receiver_account.txt ]]; then
        echo "Receiver account not found"
    else
        echo "$(jcli rest v0 account get $(cat ~/files/receiver_account.txt) -h http://127.0.0.1:${REST_PORT}/api)"
    fi
}

function get_ip() {
    # Server ip address
    echo "${PUBLIC_IP_ADDR}"
}

function get_process() {
    # Jormungandr process details
    ps auxf | grep jormungand > ~/files/buffer
    cat ~/files/buffer | grep jormungandr
}

function get_pid() {
    # Jormungandr pid
    process=`get_process`
    gotProcess=`echo $process | wc -w`
    if [[ $gotProcess -eq 0 ]]; then
        echo "Not running"
    else
        echo $process | awk '{print $2}'
    fi
}

function memory() {
    # Available memory
    top -o %MEM
}

function nodes() {
    # List of attached nodes
    echo "Proto Recv-Q Send-Q Local Address           Foreign Address         State"
    nodes="$(netstat -tupan | grep jor | grep EST | cut -c 1-80)"
    total="$(netstat -tupan | grep jor | grep EST | cut -c 1-80 | wc -l)"
    printf "%s\n" "${nodes}" "----------" "Total:" "${total}"
}

function sockets() {
    # List of used sockets
    netstat -tn | tail -n +3 | awk "{ print \$6 }" | sort | uniq -c | sort -n
}

function num_open_files() {
    # Total number of open files (my processes)
    echo "Calculating number of open files..."
    echo "$(lsof -u $(whoami) | wc -l)"
}

function is_pool_visible() {
    # Staking pool visible
    if [[ ! -f ~/files/node_scret.yaml ]]; then
        echo "Secret key not found"
    else
        stake_pool_id="$(cat ~/files/node_secret.yaml | grep node_id | awk -F: '{print $2 }')"
        echo "Display my stake pool id if it is visible on the blockchain. Otherwise, return nothing."
        echo ${GREEN}$(jcli rest v0 stake-pools get --host "http://127.0.0.1:${REST_PORT}/api" | grep $stake_pool_id)
    fi
}

function start_leader() {
    # Start jormungandr as a slot leader
    GREEN=$(printf "\033[0;32m")
    if [[ ! -f ~/files/node_scret.yaml ]]; then
        echo "Secret key not found"
    else
        nohup jormungandr --config ~/files/node-config.yaml --secret ~/files/node_secret.yaml --genesis-block-hash ${GENESIS_BLOCK_HASH} >> ~/logs/node.out 2>&1 &
        sleep 1
        get_pid
    fi
}

function logs() {
    # Last 60 lines from logs
    tail -n 60 ~/logs/node.out
}

function empty_logs() {
    # Clear logs
    > ~/logs/node.out
}

function ping_peers() {
    # Ping all trusted peers
    sed -e '/ address/!d' -e '/#/d' -e 's@^.*/ip./\([^/]*\)/tcp/\([0-9]*\).*@\1 \2@' ~/files/node-config.yaml | \
    while read addr port
    do
        tcpping -x 1 $addr $port
    done
}

function check_peers() {
    # Check if trusted peers are open
    echo "Checking trusted peers..."
    ping_peers | cut -d' ' -f3,4,7,8
}

function leader_logs() {
    # View leader logs
    if [[ ! -f ~/files/node_scret.yaml ]]; then
        echo "Secret key not found"
    else
        echo "Checking leader logs for my IP address..."
        echo "$(jcli rest v0 leaders logs get -h http://127.0.0.1:${REST_PORT}/api)"
    fi
}

function schedule() {
    # View slot leader schedule
    if [[ ! -f ~/files/node_scret.yaml ]]; then
        echo "Secret key not found"
    else
        echo "Node block generation schedule for this epoch..."
        leader_logs | grep scheduled_at_date | cut -d'"' -f2 | cut -d'.' -f2 | sort -g
    fi
}

function when() {
    # When am I scheduled to be a slot leader
    if [[ ! -f ~/files/node_scret.yaml ]]; then
        echo "Secret key not found"
    else
        leader_logs | grep scheduled_at_time | sort
    fi
}

function elections() {
    # List of slot leader elections for my node
    if [[ ! -f ~/files/node_scret.yaml ]]; then
        echo "Secret key not found"
    else
        echo "Slots I have been elected to be leader..."
        echo "$(jcli rest v0 leaders logs get -h http://127.0.0.1:${REST_PORT}/api | grep created_at_time | wc -l)"
    fi
}

function pool_stats() {
    # Staking pool statistics
    if [[ ! -f ~/files/stake_pool.id ]]; then
        echo "Pool id not found"
    else
        echo "$(jcli rest v0 stake-pool get $(cat ~/files/stake_pool.id) -h http://127.0.0.1:${REST_PORT}/api)"
    fi
}

function problems() {
    # Errors in logs
    grep -E -i 'cannot|stuck|exit|unavailable' ~/logs/node.out | tee ~/files/buffer
    if [[ ! -s ~/files/buffer ]]; then
        echo "No problems"
    fi
}

function jail() {
    # Quarantined ip addresses
    echo "List of IP addresses that were quarantined recently..."
    curl http://127.0.0.1:${REST_PORT}/api/v0/network/p2p/quarantined | rg -o "/ip4/.{0,16}" | tr -d '/ip4tcp' | uniq -u
    echo "(end)"
}

function busted() {
    # Check my quarantine status
    echo "Checking quarantine..."
    this_node=`jail | rg "${PUBLIC_IP_ADDR}"`
    if [[ ! -z ${this_node} ]]; then
        echo "Busted! I was quarantined recently (Use 'nodes' to check node connections)"
    else
        echo "Not quarantined."
    fi
}

function jail_count() {
    # Number of quarantined ip addresses
    echo "Quarantined ip address count..."
    jail | wc -l
}

function blocked() {
    # List of UFW blocked ip addresses
    echo "IP addresses recently blocked by UFW..."
    sudo tail -n 150 /var/log/syslog | grep UFW | grep TCP
    echo "(end)"
}

function nblocked() {
    # Number of UFW blocked ip addresses
    echo "IP addresses blocked by UFW..."
    sudo cat /var/log/syslog | grep UFW | grep TCP | wc -l
}

function disk_speed() {
    # Disk speed
    echo "Disk-write speed in MB/s..."
    dd if=/dev/zero of=/tmp/output conv=fdatasync bs=384k count=1k; rm -f /tmp/output
}

function frags() {
    # Get fragment info
    jcli rest v0 message logs -h http://127.0.0.1:${REST_PORT}/api
}

function fragids(){
    # Get list of fragment ids
    frags | grep "fragment_id"
}

function nfrags() {
    # Number of frags
    fragc=`fragids | wc -l`
    echo -e "Number of fragments is "$fragc
}

function get_block(){
    # Get block contents
    if [[ -z $1 ]]; then
        echo "Blockid required"
    else
        jcli rest v0 block $1 get
    fi
}

function portsentry_stats() {
    sudo grep portsentry /var/log/syslog | awk '{print $6}' | sort | uniq -c
}

function settings() {
    echo "$(jcli rest v0 settings get --host ${REST_URL})"
}

function tip() {
    grep tip ~/logs/node.out
}

function current_blocktime() {
    chainstartdate=$(settings | grep "block0Time:" | awk '{print $2}' | tr -d '"' | xargs -I{} date "+%s" -d {})
    nowtime=$(date +%s)
    chaintime=$(($nowtime-$chainstartdate))
    slot=$((($chaintime % 86400)))
    epoch=$(($chaintime / 86400))
}

function next() {
    # Next scheduled as slot leader
    if [[ ! -f ~/files/node_scret.yaml ]]; then
        echo "Secret key not found"
    else
        newEpoch=$(stats | grep Date | grep -Eo '[0-9]{1,3}' | awk 'NR==1{print $1}')
        maxSlots=$(leader_logs | grep -P 'scheduled_at_date: "'$newEpoch'.' | grep -P '[0-9]+' | wc -l)
        leaderSlots=$(leader_logs | grep -P 'scheduled_at_date: "'$newEpoch'.' | grep -P '[0-9]+' | awk -v i="$rowIndex" '{print $2}' | awk -F "." '{print $2}' | tr '"' ' ' | sort -V)
        for (( rowIndex = 1; rowIndex <= $maxSlots ; rowIndex++ ))
        do
            current_blocktime
            currentSlotTime=$((slot/2))
            #currentSlotTime=$(stats | grep 'lastBlockDate: "'$newEpoch'.' | awk -F "." '{print $2}' | tr '"' ' ')
            blockCreatedSlotTime=$(awk -v i="$rowIndex" 'NR==i {print $1}' <<< $leaderSlots)

            if [[ $blockCreatedSlotTime -ge $currentSlotTime ]];
            then
                timeToNextSlotLead=$(($blockCreatedSlotTime-$currentSlotTime))
                currentTime=$(date +%s)
                nextBlockDate=$(($chainstartdate+$blockCreatedSlotTime*2+($epoch)*86400))
                echo "TimeToNextSlotLead: " $(awk '{print int($1/(3600*24))":"int($1/60)":"int($1%60)}' <<< $(($timeToNextSlotLead*2))) "("$(awk '{print strftime("%c",$1)}' <<< $nextBlockDate)") - $(($blockCreatedSlotTime))"
                break;
            fi
        done
    fi
}

function shelleyLast3() {
    # Contact IOHK testnet explorer to get last 3 blocks
    shelleyResult=`curl -X POST -H "Content-Type: application/json" --data '{"query": " query {   allBlocks (last: 3) {    pageInfo { hasNextPage hasPreviousPage startCursor endCursor  }  totalCount  edges {    node {     id  date { slot epoch {  id  firstBlock { id  }  lastBlock { id  }  totalBlocks }  }  transactions { totalCount edges {   node {    id  block { id date {   slot   epoch {    id  firstBlock { id  }  lastBlock { id  }  totalBlocks   } } leader {   __typename   ... on Pool {    id  blocks { totalCount  }  registration { startValidity managementThreshold owners operators rewards {   fixed   ratio {  numerator  denominator   }   maxLimit } rewardAccount {   id }  }   } }  }  inputs { amount address {   id }  }  outputs { amount address {   id }  }   }   cursor }  }  previousBlock { id  }  chainLength  leader { __typename ... on Pool {  id  blocks { totalCount  }  registration { startValidity managementThreshold owners operators rewards {   fixed   ratio {  numerator  denominator   }   maxLimit } rewardAccount {   id }  } }  }    }    cursor  }   } }  "}' https://explorer.incentivized-testnet.iohkdev.io/explorer/graphql 2> /dev/null`
}

function delta() {
    # Compare my node with shelley block count
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    ORANGE='\033[0;33m'
    NC='\033[0m' # No Color
    lastBlockHash=`stats | head -n 6 | tail -n 1 | awk '{print $2}'`
    lastBlockNum=`stats | head -n 7 | tail -n 1 | awk '{print $2}' | tr -d \"`
    if [[ ! $lastBlockNum =~ ^[0-9]+$ ]]; then
        lastBlockNum=None
    fi
    now=$(date +"%r")
    tries=6
    deltaMax=10
    counter=0

    while [[ $counter -le $tries ]]
    do
        shelleyLast3
        shelleyBlocks=`echo $shelleyResult | grep -m 1 -o '"chainLength":"[^"]*' | cut -d'"' -f4`
        shelleyBlockNum=`echo $shelleyBlocks | cut -d ' ' -f3`
        deltaBlockCount=`echo $(($shelleyBlockNum-$lastBlockNum))`
        if [[ ! -z $shelleyBlockNum ]]; then
            break
        fi

        counter=$(($counter+1))
        echo -e ${RED}"Invalid result, retrying..."${NC}
        sleep 3
    done

    if [[ -z "$shelleyBlockNum" ]]; then
        echo -e ${RED}"Invalid fork."${NC}
    else
        deltaBlockCount=`echo $(($shelleyBlockNum-$lastBlockNum))`
    fi

    echo "My last block: " $lastBlockNum
    echo "Shelley block: " $shelleyBlockNum
    echo "Delta        : " $deltaBlockCount

    # Next scheduled to be a slot leader
    if [[ -f ~/files/node_scret.yaml ]]; then
        next
    fi

    if [[ -z $lastBlockNum || ! $lastBlockNum =~ ^[0-9]+$ ]]; then
        echo -e "$now: My node is starting or not running. Use 'stats' to get more info."
        return
    fi
    if [[ $deltaBlockCount -lt $deltaMax && $deltaBlockCount -gt 0 ]]; then
        echo -e ${ORANGE}"$now: WARNING: My node is starting to drift. It could end up on a fork soon."${NC}
        return
    fi
    if [[ $deltaBlockCount -gt $deltaMax ]]; then
        echo -e ${RED}"$now: WARNING: My node might be forked."${NC}
        jcli rest v0 node stats get -h http://127.0.0.1:${REST_PORT}/api | grep lastBlockHash
        return
    fi
    if [[ $deltaBlockCount -le 0 && deltaBlockCount -ge -2 ]]; then
        echo -e ${GREEN}"$now: My node is running well."${NC}
        return
    fi
    if [[ $deltaBlockCount -lt 0 ]]; then
        echo -e ${RED}"$now: WARNING: My node is ahead of the chain. It could be forked."${NC}
        jcli rest v0 node stats get -h http://127.0.0.1:${REST_PORT}/api | grep lastBlockHash
        return
    fi
}

function commands(){
    # Command list
    GREEN='\033[0;32m'
    NC='\033[0m' # No Color
    echo "Command list:"
    echo -e ${GREEN}"start"${NC}": Start jormungandr"
    echo -e ${GREEN}"stop"${NC}": Stop jormungandr"
    echo -e ${GREEN}"stats"${NC}": Current node status"
    echo -e ${GREEN}"logs"${NC}": Show last 60 lines from jormungandr log"
    echo -e ${GREEN}"empty_logs"${NC}": Clear logs"
    echo -e ${GREEN}"delta"${NC}": Show difference between node block and latest block"
    echo -e ${GREEN}"bal"${NC}": Wallet balance"
    echo -e ${GREEN}"get_ip"${NC}": Get ip address of this server"
    echo -e ${GREEN}"get_process"${NC}": Get jormungandr process details"
    echo -e ${GREEN}"get_pid"${NC}": Get jormungandr process id"
    echo -e ${GREEN}"memory"${NC}": Show memory usage (q to quit)"
    echo -e ${GREEN}"nodes"${NC}": Connected nodes"
    echo -e ${GREEN}"sockets"${NC}": Number of open sockets"
    echo -e ${GREEN}"num_open_files"${NC}": Number of currently open files"
    echo -e ${GREEN}"is_pool_visible"${NC}": Check if pool is visible on the blockchain"
    echo -e ${GREEN}"start_leader"${NC}": Start node as a leader"
    echo -e ${GREEN}"check_peers"${NC}": Check peers in trusted peers list"
    echo -e ${GREEN}"ping_peers"${NC}": Show ping results for trusted peers list"
    echo -e ${GREEN}"leader_logs"${NC}": Show leader logs"
    echo -e ${GREEN}"schedule"${NC}": Node block generation schedule for this epoch"
    echo -e ${GREEN}"jail"${NC}": List of quarantined nodes"
    echo -e ${GREEN}"jail_count"${NC}": Number of quarantined nodes"
    echo -e ${GREEN}"busted"${NC}": Show quarantine status for this node"
    echo -e ${GREEN}"when"${NC}": Show when node is scheduled to create a block"
    echo -e ${GREEN}"elections"${NC}": Show election stats"
    echo -e ${GREEN}"pool_stats"${NC}": Show pool statistics"
    echo -e ${GREEN}"problems"${NC}": Scan log for errors"
    echo -e ${GREEN}"blocked"${NC}": List of ip addresses recently blocked by UFW"
    echo -e ${GREEN}"nblocked"${NC}": Number of ip addresses blocked by UFW"
    echo -e ${GREEN}"disk_speed"${NC}": Show disk write speed"
    echo -e ${GREEN}"frags"${NC}": Show current fragment info"
    echo -e ${GREEN}"fragids"${NC}": Show list of fragment ids"
    echo -e ${GREEN}"nfrags"${NC}": Show current frag count"
    echo -e ${GREEN}"portsentry_stats"${NC}": Port sentry stats"
    echo -e ${GREEN}"tip"${NC}": Search logs for current branch tip updates"
    echo -e ${GREEN}"next"${NC}": Next scheduled block for leader"
    echo -e ${GREEN}"get_block blockid"${NC}": Get contents of a blockid from my blockchain"
}
