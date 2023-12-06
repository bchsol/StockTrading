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

    struct Step{
        uint256 nextPrice;
        uint256 prevPrice;
        uint256 quantity;
    }

    PrivateEquity[] privateEquity;

    mapping(address => mapping(string => uint256)) public balances;

    mapping(string => mapping(uint256 => Step)) public buySteps;
    mapping(string => mapping(uint256 => uint8)) public buyOrderCounter;
    uint256 public maxBuyPrice;

    mapping(string => mapping(uint256 => Step)) public sellSteps;
    mapping(string => mapping(uint256 => uint8)) public sellOrderCounter;
    uint256 public minSellPrice;

    mapping(string => mapping(uint256 => Order[])) public buyOrders;
    mapping(string => mapping(uint256 => Order[])) public sellOrders;

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

    function voteIPO(uint256 index) external {
        require(!containsVotedAddress(index,msg.sender), "already voted");
        require(privateEquity[index].owner != msg.sender, "owner cannot vote");

        privateEquity[index].voteCount++;
        privateEquity[index].votedAddress.push(msg.sender);

        if(privateEquity[index].voteCount >= 100) {
            privateEquity[index].passed = true;
        }
    }

    function passedIPO(uint256 index) external {
        require(privateEquity[index].passed);

        uint256 totalVotedAddress = privateEquity[index].votedAddress.length;

        uint256 majorStake = privateEquity[index].quantity / 2;

        if(privateEquity[index].quantity % 2 == 1) {
            majorStake += 1;
        }
        addStock(privateEquity[index].stockName, privateEquity[index].owner, majorStake);

        
        uint256 minorStake = privateEquity[index].quantity - majorStake;
        for(uint i = 0; i < totalVotedAddress; i++) {
            address voter = privateEquity[index].votedAddress[i];
            balances[voter][privateEquity[index].stockName] += minorStake / totalVotedAddress;
        }

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
        
        if(index  < privateEquity.length - 1) {
            privateEquity[index] = privateEquity[privateEquity.length - 1];
        }
        privateEquity.pop();
    }

    function hasVoted(uint256 index, address voter) public view returns (bool) {
        require(index < privateEquity.length, "Invalid index");
        return containsVotedAddress(index,voter);
    }
    
    function placeBuyOrder(string memory stockName, uint256 price, uint32 quantity) external {
        uint256 sellPricePointer = minSellPrice;
        uint256 amountReflect = quantity;
        uint256 zeroIdxLen;

        if (minSellPrice > 0 && price >= minSellPrice) {
            while (amountReflect > 0 && sellPricePointer <= price && sellPricePointer != 0) {
                zeroIdxLen = 0;
                uint256 nextPrice = sellSteps[stockName][sellPricePointer].nextPrice;
                uint256 orderCount = sellOrderCounter[stockName][sellPricePointer];
                for(uint i = 0; i < orderCount && amountReflect > 0; i++) {
                    address seller = sellOrders[stockName][sellPricePointer][i].trader;
                    if(amountReflect >= sellOrders[stockName][sellPricePointer][i].quantity) {
                        amountReflect -= sellOrders[stockName][sellPricePointer][i].quantity;
                        balances[seller][stockName] -= sellOrders[stockName][sellPricePointer][i].quantity;
                        balances[msg.sender][stockName] += sellOrders[stockName][sellPricePointer][i].quantity;

                        delete sellOrders[stockName][sellPricePointer][i];
                        sellOrderCounter[stockName][sellPricePointer] -= 1;

                        zeroIdxLen++;

                        if(sellOrderCounter[stockName][sellPricePointer] == 0) {
                            if(nextPrice > 0) {
                                sellSteps[stockName][nextPrice].prevPrice = 0;
                            }
                            delete sellSteps[stockName][sellPricePointer];
                            minSellPrice = nextPrice;
                            sellPricePointer = nextPrice;
                        }
                    } else {
                        sellSteps[stockName][sellPricePointer].quantity -= amountReflect;
                        sellOrders[stockName][sellPricePointer][i].quantity -= amountReflect;

                        balances[seller][stockName] -= amountReflect;
                        balances[msg.sender][stockName] += amountReflect;
                        amountReflect = 0;
                    }
                    
                }
                
            }
        }
        if(zeroIdxLen > 0) {
            _alignSellOrder(stockName, sellPricePointer, zeroIdxLen);
        }
                
        if (amountReflect > 0) {
            _drawToBuyBook(stockName, price, amountReflect);
        }
    }


    function placeSellOrder(string memory stockName, uint256 price, uint256 quantity) external {
        uint256 buyPricePointer = maxBuyPrice;
        uint256 amountReflect = quantity;
        uint256 zeroIdxLen;
        if (maxBuyPrice > 0 && price <= maxBuyPrice) {
            while (amountReflect > 0 && buyPricePointer >= price && buyPricePointer != 0) {
                zeroIdxLen = 0;
                uint256 prevPrice = buySteps[stockName][buyPricePointer].prevPrice;
                uint256 orderCount = buyOrderCounter[stockName][buyPricePointer];
                for(uint i = 0; i < orderCount && amountReflect > 0; i++) {
                    address buyer = buyOrders[stockName][buyPricePointer][i].trader;
                    if(amountReflect >= buyOrders[stockName][buyPricePointer][i].quantity) {
                        amountReflect -= buyOrders[stockName][buyPricePointer][i].quantity;

                        balances[buyer][stockName] += buyOrders[stockName][buyPricePointer][i].quantity;
                        balances[msg.sender][stockName] -= buyOrders[stockName][buyPricePointer][i].quantity;

                        delete buyOrders[stockName][buyPricePointer][i];
                        buyOrderCounter[stockName][buyPricePointer] -= 1;

                        zeroIdxLen++;

                        if(buyOrderCounter[stockName][buyPricePointer] == 0) {
                            if(prevPrice > 0) {
                                buySteps[stockName][prevPrice].nextPrice = 0;
                            }
                            delete buySteps[stockName][buyPricePointer];
                            maxBuyPrice = prevPrice;
                            buyPricePointer = prevPrice;
                        }
                    } else {
                        buySteps[stockName][buyPricePointer].quantity -= amountReflect;
                        buyOrders[stockName][buyPricePointer][i].quantity -= amountReflect;

                        balances[buyer][stockName] += amountReflect;
                        balances[msg.sender][stockName] -= amountReflect;
                        amountReflect = 0;
                    }
                    
                }
                
            }
        }

        if(zeroIdxLen > 0) {
            _alignBuyOrder(stockName, buyPricePointer, zeroIdxLen);
        }

        if (amountReflect > 0) {
            _drawToSellBook(stockName, price, amountReflect);
        }
    }


    function _alignBuyOrder(string memory stockName, uint256 price, uint256 len) internal {
        Order[] storage orders = buyOrders[stockName][price];
        for (uint256 i = 0; i+len < orders.length; i++) {
            orders[i] = orders[i+len];
        }
        for(uint256 i = 0; i < len; i++) {
            orders.pop();
        }
    }

    function _alignSellOrder(string memory stockName, uint256 price, uint256 len) internal {
        Order[] storage orders = sellOrders[stockName][price];
        for (uint256 i = 0; i+len < orders.length; i++) {
            orders[i] = orders[i+len];
        }
        for(uint256 i = 0; i < len; i++) {
            orders.pop();
        }
    }

    function _drawToBuyBook (
        string memory stockName,
        uint256 price,
        uint256 quantity
    ) internal {
        require(price > 0, "Can not place order with price equal 0");

        buyOrderCounter[stockName][price] += 1;

        buyOrders[stockName][price].push(Order(msg.sender, quantity, block.timestamp));

        buySteps[stockName][price].quantity += quantity;

        if (maxBuyPrice == 0) {
            maxBuyPrice = price;
            return;
        }

        if (price > maxBuyPrice) {
            buySteps[stockName][maxBuyPrice].nextPrice = price;
            buySteps[stockName][price].prevPrice = maxBuyPrice;
            maxBuyPrice = price;
            return;
        }

        if (price == maxBuyPrice) {
            return;
        }

        uint256 buyPricePointer = maxBuyPrice;
        while (price <= buyPricePointer && buySteps[stockName][buyPricePointer].prevPrice != 0) {
            buyPricePointer = buySteps[stockName][buyPricePointer].prevPrice;
        }

        if(buyPricePointer > price) {
            buySteps[stockName][price].nextPrice = buyPricePointer;
            buySteps[stockName][buyPricePointer].prevPrice = price;
        }

        if (buyPricePointer < price && price < buySteps[stockName][buyPricePointer].nextPrice) {
            buySteps[stockName][price].nextPrice = buySteps[stockName][buyPricePointer].nextPrice;
            buySteps[stockName][price].prevPrice = buyPricePointer;

            buySteps[stockName][buySteps[stockName][buyPricePointer].nextPrice].prevPrice = price;
            buySteps[stockName][buyPricePointer].nextPrice = price;
        }
        
    }

    function _drawToSellBook (
        string memory stockName,
        uint256 price,
        uint256 quantity
    ) internal {
        require(price > 0, "Can not place order with price equal 0");

        sellOrderCounter[stockName][price] += 1;
        sellOrders[stockName][price].push(Order(msg.sender, quantity, block.timestamp));
        sellSteps[stockName][price].quantity += quantity;


        if (minSellPrice == 0) {
            minSellPrice = price;
            return;
        }

        if (price < minSellPrice) {
            sellSteps[stockName][minSellPrice].prevPrice = price;
            sellSteps[stockName][price].nextPrice = minSellPrice;
            minSellPrice = price;
            return;
        }

        if (price == minSellPrice) {
            return;
        }

        uint256 sellPricePointer = minSellPrice;
        while (price >= sellPricePointer && sellSteps[stockName][sellPricePointer].nextPrice != 0) {
            sellPricePointer = sellSteps[stockName][sellPricePointer].nextPrice;
        }

        if (sellPricePointer < price) {
            sellSteps[stockName][price].prevPrice = sellPricePointer;
            sellSteps[stockName][sellPricePointer].nextPrice = price;
        }

        if (sellPricePointer > price && price > sellSteps[stockName][sellPricePointer].prevPrice) {
            sellSteps[stockName][price].prevPrice = sellSteps[stockName][sellPricePointer].prevPrice;
            sellSteps[stockName][price].nextPrice = sellPricePointer;

            sellSteps[stockName][sellSteps[stockName][sellPricePointer].prevPrice].nextPrice = price;
            sellSteps[stockName][sellPricePointer].prevPrice = price;
        }
    }

    function addStock(string memory stockName, address shareholder, uint256 quantity) public {
        balances[shareholder][stockName] += quantity;
    }
}
