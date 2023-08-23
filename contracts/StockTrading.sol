// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract StockTrading {
    struct PrivateEquity {
        address owner;
        string stockName;
        uint256 quantity;
        uint256 price;
        uint256 voteCount;
        bool passed;
        address[] votedAddress;
    }

    struct Stock {
        address owner;
        string stockName;
        uint256 quantity;
        uint256 price;
    }

    struct Order {
        address trader;
        uint256 quantity;
        uint256 timeStamp;
    }

    mapping(address => mapping(string => uint256)) public balances;

    mapping(string => mapping(uint256=>Order[])) public buyOrders;
    mapping(string => mapping(uint256=>Order[])) public sellOrders;

    //mapping(string => mapping(uint256=>Order[])) public privBuyOrders;
    //mapping(string => mapping(uint256=>Order[])) public privSellOrders;

    mapping(string => uint256) public highestBuyPrice;
    mapping(string => uint256) public lowestSellPrice;

    PrivateEquity[] privateEquity;

    // 비상장
    function listingPrivateEquity(string memory stockName, uint256 quantity, uint256 price) external {
        PrivateEquity memory newPrivateEquity = PrivateEquity(msg.sender, stockName, quantity, price, 0, false, new address[](0));
        privateEquity.push(newPrivateEquity);
    }

    function containsVotedAddress(uint256 index, address voter) internal view returns(bool){
        PrivateEquity storage equity = privateEquity[index];
        for(uint i = 0; i < equity.votedAddress.length; i++) {
            if(equity.votedAddress[i] == voter) {
                return true;
            }
        }
        return false;
    }

    // 청약
    function voteIPO(uint256 index) external {
        // privateEquity 투표
        require(!containsVotedAddress(index,msg.sender), "already voted");
        require(privateEquity[index].owner != msg.sender, "owner cannot vote");

        privateEquity[index].voteCount++;
        privateEquity[index].votedAddress.push(msg.sender);

        if(privateEquity[index].voteCount >= 100) {
            privateEquity[index].passed = true;
        }
    }

    // 상장 주식 배분
    function passedIPO(uint256 index) external {
        // privateEquity에서 Stock으로 넘어가는 단계
        //require(privateEquity[index].passed);

        uint256 totalVotedAddress = privateEquity[index].votedAddress.length;

        // 대주주 50& 나머지 50%배분
        uint256 majorStake = privateEquity[index].quantity / 2;

        // 나머지 1남을경우
        if(privateEquity[index].quantity % 2 == 1) {
            majorStake += 1;
        }
        addStock(privateEquity[index].stockName, privateEquity[index].owner, majorStake);

        // 일반 주주 배분
        uint256 minorStake = privateEquity[index].quantity - majorStake;
        for(uint i = 0; i < totalVotedAddress; i++) {
            address voter = privateEquity[index].votedAddress[i];
            balances[voter][privateEquity[index].stockName] += minorStake / totalVotedAddress;
        }

        // 나머지 랜덤 1주씩 배분
        uint256 remainingStake = minorStake % totalVotedAddress;
        if(remainingStake != 0) {
            for(uint i = 0; i < remainingStake; i++) {
                uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % totalVotedAddress;
                address randomVoter = privateEquity[index].votedAddress[randomIndex];

                if(containsVotedAddress(index, randomVoter)) {
                    balances[randomVoter][privateEquity[index].stockName]++;
                    privateEquity[index].votedAddress.push(randomVoter);
                }
            }
        }
        
        // delete privateEquity[index]
        if(index  < privateEquity.length - 1) {
            privateEquity[index] = privateEquity[privateEquity.length - 1];
        }
        privateEquity.pop();
    }

    function hasVoted(uint256 index, address voter) public view returns (bool) {
        require(index < privateEquity.length, "Invalid index");
        return containsVotedAddress(index,voter);
    }

    function placeBuyOrder(string memory stockName, uint256 price, uint256 quantity) external {
        if(sellOrders[stockName][price].length > 0) {
            uint256 remainingQuantity = quantity;
            for(uint i = 0; i < sellOrders[stockName][price].length && remainingQuantity > 0; i++) {
                uint256 quantityToBuy = sellOrders[stockName][price][i].quantity <= remainingQuantity ? sellOrders[stockName][price][i].quantity : remainingQuantity;

                remainingQuantity -= quantityToBuy;
                sellOrders[stockName][price][i].quantity -= quantityToBuy;

                balances[msg.sender][stockName] += quantityToBuy;
                balances[sellOrders[stockName][price][i].trader][stockName] -= quantityToBuy;
            }

            buyOrders[stockName][price].push(Order(msg.sender, remainingQuantity, block.timestamp));
            removeOrders(sellOrders[stockName][price]);
            if(buyOrders[stockName][price].length == 0) {
                highestBuyPrice[stockName] = 0;
            }
        } else {
            buyOrders[stockName][price].push(Order(msg.sender,quantity, block.timestamp));
            if(highestBuyPrice[stockName] == 0 || highestBuyPrice[stockName] < price) {
                highestBuyPrice[stockName] = price;
            }
        }
    }

    function placeSellOrder(string memory stockName, uint256 price, uint256 quantity) external {
        if(buyOrders[stockName][price].length > 0) {
            uint256 remainingQuantity = quantity;
            for(uint i = 0; i < buyOrders[stockName][price].length && remainingQuantity > 0; i++) {
                uint256 quantityToSell = buyOrders[stockName][price][i].quantity <= remainingQuantity ? buyOrders[stockName][price][i].quantity : remainingQuantity;

                remainingQuantity -= quantityToSell;
                buyOrders[stockName][price][i].quantity -= quantityToSell;

                balances[msg.sender][stockName] -= quantityToSell;
                balances[buyOrders[stockName][price][i].trader][stockName] += quantityToSell;
            }

            sellOrders[stockName][price].push(Order(msg.sender, remainingQuantity, block.timestamp));
            removeOrders(buyOrders[stockName][price]);
            if(sellOrders[stockName][price].length == 0) {
                lowestSellPrice[stockName] = 0;
            }

        } else {
            sellOrders[stockName][price].push(Order(msg.sender, quantity, block.timestamp));
            if(lowestSellPrice[stockName] == 0 || price < lowestSellPrice[stockName]) {
                lowestSellPrice[stockName] = price;
            }
        }
    }

    function addStock(string memory stockName, address shareholder, uint256 quantity) internal {
        balances[shareholder][stockName] += quantity;
    }

    function removeOrders(Order[] storage orders) internal {
        uint256 i = 0;
        while(i < orders.length) {
            if(orders[i].quantity == 0) {
                if(i < orders.length - 1) {
                    orders[i] = orders[orders.length - 1];
                }
                orders.pop();
            } else {
                i++;
            }
        }
    }
}
