// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title WrappedVoxaLinkPro
 * @dev ERC20 Token, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 */

contract WrappedVoxaLinkPro is ERC20, Ownable {

    /**
     * @dev Sets the values for {name}, {symbol}, and mints the initial supply to the creator.
     * All three of these values are immutable: they can only be set once during construction.
     * @param owner Address to whom the initial tokens will be minted.
     * @param amount The amount of tokens to mint initially.
     */
    
    constructor(address owner, uint256 amount) ERC20("Wrapped VoxaLinkPro", "wVXLP") Ownable(msg.sender) {
        _mint(owner, amount);
    }

        /**
     * @dev Burns a specific amount of tokens from the caller's account.
     * @param amount The amount of token to be burned.
     */

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}   

   
/**
 * @title VoxaLinkProICO
 * @dev This contract manages the ICO for VoxaLinkPro tokens. It allows for buying tokens in different phases,
 * with different rates and bonuses, and tracks funds raised in each phase.
 */
contract VoxaLinkProICO is ReentrancyGuard, Ownable, Pausable {
    WrappedVoxaLinkPro public wVXLP;
    address payable public wallet;
    uint256 public constant MAX_PURCHASE = 2.5e6 ether;
    uint256[] public phaseRates = [50, 65, 80]; // Prices in USD cents
    uint256[] public fixedRates = [50, 65, 80];
    uint256[] public bonusRates = [7, 5, 0]; // Bonus rates in percentage
    uint256[] public phaseTokenAllocations = [200e6 ether, 120e6 ether, 80e6 ether]; // 200M, 120M, 80M
    uint256 public fundsRaisedPrivateSale = 0;
    uint256 public fundsRaisedPreSale = 0;
    uint256 public fundsRaisedPublicSale = 0;
    AggregatorV3Interface internal priceFeed;

    enum Phase { NotStarted, PrivateSale, PreSale, PublicSale, Ended }
    Phase public currentPhase;

    uint256 public icoStartTime;
    uint256[] public phaseEndTimes = [0, 0, 0];
    uint256[] public phaseDurations = [3456000, 2592000, 1728000]; // 40, 30, 20 days in seconds

    uint256 public lastPolledTime;

    // event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);
    // event PhaseExtended(uint8 phase, uint256 newEndTime);
    // event PhaseRateUpdated(uint8 phase, uint256 newRate);
    // event RateUpdated(uint256 ratePrivateSale, uint256 ratePreSale, uint256 ratePublicSale);
    // event ICOFinalized();
    // event PhaseUpdated(Phase newPhase);

    
    mapping(address => uint256[3]) public purchases; // Array Index will indicate the Phase Number

        /**
     * @dev Constructor sets the initial wallet to collect funds, creates the token, and sets the price feed.
     * @param _wallet Address where collected funds will be sent.
     * @param _priceFeed Address of the Chainlink Price Feed contract.
     */

    constructor(address payable _wallet, address _priceFeed) payable Ownable(msg.sender) {
        require(_wallet != address(0), "Wallet address cannot be zero");
        wVXLP = new WrappedVoxaLinkPro(address(this), 420e24); // 420M
        wallet = _wallet;
        lastPolledTime = block.timestamp; 
        currentPhase = Phase.NotStarted;
        priceFeed = AggregatorV3Interface(_priceFeed);
    }
    
        /**
     * @dev Starts the ICO by changing the phase to PrivateSale and setting the start time and end times for phases.
     * Requires that the ICO has not started or already completed.
     */
    
    function startICO() public onlyOwner {
        require(currentPhase == Phase.NotStarted, "ICO has already started or completed"); // 
        currentPhase = Phase.PrivateSale;
        icoStartTime = block.timestamp;
        lastPolledTime = icoStartTime;
        updatePhaseEndTimes();
        updateRate();
    }

       /**
     * @dev Allows users to buy tokens. Checks if the phase has ended and moves to next phase if necessary.
     * Updates the rate every hour. Transfers the purchased tokens to the buyer and forwards the funds to the wallet.
     * Requires that the ICO is in an active phase and not paused.
     */

    function buyTokens() external payable nonReentrant whenNotPaused {
        require(currentPhase != Phase.NotStarted && currentPhase != Phase.Ended, "Can't buy tokens in this phase.");
        if (phaseEndTimes[uint8(currentPhase)-1] <= block.timestamp) {
            moveToNextPhase();
            lastPolledTime = block.timestamp;
        }
        if (block.timestamp  >= (3600 + lastPolledTime)) {
            updateRate();
            lastPolledTime = block.timestamp;
        }
        
        uint256 currentRate = phaseRates[uint(currentPhase) - 1]; 
        processPurchase(msg.sender, msg.value, currentRate);
        wallet.transfer(msg.value); 
    }

    /**
     * @dev Internal function to process the token purchase. Calculates the total number of tokens (including bonuses)
     * and updates the token allocation for the phase. Also updates the funds raised.
     * @param purchaser Address of the buyer.
     * @param weiAmount The amount of Ether sent by the buyer.
     * @param currentRate The current rate of tokens per Ether.
     */

    function processPurchase(address purchaser, uint256 weiAmount, uint256 currentRate) internal {
        require(weiAmount > 0, "Zero purchase not allowed");

        (uint256 baseTokens, uint256 totalTokens) = calculateTotalTokens(weiAmount, currentRate, uint(currentPhase)-1);

        
        uint256 cumulativeAmount = 0;

        for (uint i = 0; i < purchases[purchaser].length; i++) {
            cumulativeAmount = cumulativeAmount + purchases[purchaser][i];
        }

        require(cumulativeAmount + baseTokens <= MAX_PURCHASE, "Purchase exceeds maximum limit");

        require(baseTokens <= phaseTokenAllocations[uint(currentPhase)-1], "Insufficient tokens available for purchase");

        phaseTokenAllocations[uint(currentPhase)-1] = phaseTokenAllocations[uint(currentPhase)-1] - baseTokens;
        
        purchases[purchaser][uint(currentPhase)-1] = purchases[purchaser][uint(currentPhase)-1] + baseTokens;
           
        updateFundsRaised(weiAmount);
        
        // emit TokenPurchase(purchaser, weiAmount, totalTokens);
        wVXLP.transfer(purchaser, totalTokens);
    }

    /**
     * @dev Calculates the total number of tokens a buyer gets for their Ether, including any bonus.
     * @param weiAmount The amount of Ether used for the purchase.
     * @param rate The current rate of tokens per Ether.
     * @param phaseIndex The index of the current phase.
     * @return (uint256, uint256) Returns the base number of tokens and the total number of tokens including bonus.
     */

    function calculateTotalTokens(uint256 weiAmount, uint256 rate, uint phaseIndex) internal view returns (uint256, uint256) {
        uint256 tokens = (weiAmount * rate) / 1e18;
        uint256 bonus = (tokens * bonusRates[phaseIndex]) / 100;
        uint256 totalTokens = tokens + bonus;
        return (tokens, totalTokens);
    }

        /**
     * @dev Updates the funds raised in the current phase by adding the specified wei amount.
     * @param weiAmount The amount of Ether to add to the funds raised.
     */

    function updateFundsRaised(uint256 weiAmount) private {
        if (currentPhase == Phase.PrivateSale) {
            fundsRaisedPrivateSale += weiAmount;
        } else if (currentPhase == Phase.PreSale) {
            fundsRaisedPreSale += weiAmount;
        } else if (currentPhase == Phase.PublicSale) {
            fundsRaisedPublicSale += weiAmount;
        }
    }

    /**
     * @dev Moves the ICO to the next phase. Burns any unsold tokens from the current phase.
     * Requires that the ICO is in a valid phase for transition.
     */

    function moveToNextPhase() public onlyOwner {
        require(currentPhase != Phase.NotStarted && currentPhase != Phase.Ended, "Invalid phase transition");
            burnUnsoldTokens(); 
            currentPhase = Phase(uint8(currentPhase) + 1);
            if (uint8(currentPhase) != 4) {
                updateRate();
            }
            // emit PhaseExtended(uint8(currentPhase), phaseEndTimes[uint8(currentPhase) - 1]);
    }

    /**
     * @dev Internal function to burn unsold tokens from the current phase. Calculates and burns the unsold tokens
     * including any bonus tokens.
     */

    function burnUnsoldTokens() internal {
        uint256 unsoldTokens = phaseTokenAllocations[uint(currentPhase) - 1];
        uint256 remainingBonus = (unsoldTokens * bonusRates[uint(currentPhase) - 1])/100; 
        uint256 remainingTokens = unsoldTokens + remainingBonus;
        if (remainingTokens > 0) {
            wVXLP.burn(remainingTokens);
        }
    }

    /**
     * @dev Updates the rate of tokens per Ether based on the current price of Ether in USD. 
     * Requires that the ICO is in an active phase.
     */

    function updateRate() public onlyOwner {
        require(currentPhase != Phase.NotStarted && currentPhase != Phase.Ended, "Can't buy tokens in this phase.");
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data");

        uint256 ethPriceInUsd = uint256(price) * 1e10; // Convert Chainlink price to Wei for consistency
        uint256 tokenPriceInWei = fixedRates[uint(currentPhase) - 1] * 1e15; // Convert USD cents to Wei
        phaseRates[uint(currentPhase) - 1] = (1e18 * ethPriceInUsd) / tokenPriceInWei;

        // emit RateUpdated(phaseRates[0], phaseRates[1], phaseRates[2]);
    }

    /**
     * @dev Returns the remaining token allocations for each phase of the ICO.
     * @return privateSaleRemaining Tokens remaining in Private Sale.
     * @return preSaleRemaining Tokens remaining in Pre Sale.
     * @return publicSaleRemaining Tokens remaining in Public Sale.
     */
    
    function getRemainingTokensForPhase() public view returns (uint256 privateSaleRemaining, uint256 preSaleRemaining, uint256 publicSaleRemaining) {
        privateSaleRemaining = phaseTokenAllocations[0];
        preSaleRemaining = phaseTokenAllocations[1];
        publicSaleRemaining = phaseTokenAllocations[2];
        return (privateSaleRemaining, preSaleRemaining, publicSaleRemaining);
    }

    /**
     * @dev Returns the token balance of a given address.
     * @param holder The address to query the balance of.
     * @return The number of tokens owned by the passed address.
     */
     
    function getTokenBalance(address holder) public view returns (uint256) {
        return wVXLP.balanceOf(holder);
    }

    /**
     * @dev Returns the current token allocation for the ongoing ICO phase.
     * @return The number of tokens allocated for the current phase.
     */      

    function getCurrentPhaseTokenAllocation() public view returns (uint256) {
        require(currentPhase != Phase.NotStarted && currentPhase != Phase.Ended, "Can't get allocations in this phase");
        
        return phaseTokenAllocations[uint(currentPhase) - 1];
    }

    /**
     * @dev Returns the amount of funds raised in each phase of the ICO.
     * @return The funds raised in the Private Sale, Pre Sale, and Public Sale, respectively.
     */

    function getFundsRaisedByPhase() public view returns (uint256, uint256, uint256) {
        return (fundsRaisedPrivateSale, fundsRaisedPreSale, fundsRaisedPublicSale);
    }

    /**
     * @dev Returns the current phase of the ICO.
     * @return The current phase of the ICO.
     */
   
    function getCurrentPhase() public view returns (Phase) {
        return currentPhase;
    }

     /**
     * @dev Returns the end time of a specified phase.
     * @param phaseIndex The index of the phase (0 for Private Sale, 1 for Pre Sale, 2 for Public Sale).
     * @return The end time of the specified phase.
     */  
 
    function getPhaseEndTime(uint8 phaseIndex) public view returns (uint256) {
        return phaseEndTimes[phaseIndex];
    }

    /**
     * @dev Returns the purchase information for a specific address.
     * @param purchaser The address to query purchase information of.
     * @return An array representing the amount of tokens purchased in each phase by the specified address.
     */

    function getPurchaseInfo(address purchaser) public view returns (uint256[3] memory) {
        return purchases[purchaser];
     }

    /**
     * @dev Returns the total balance of tokens each phase for a specific address including bonuses.
     * @param purchaser The address to query the balance of.
     * @return An array representing the total balance of tokens for each phase for the specified address.
     */

    function getTotalBalanceEachPhase (address purchaser) public view returns (uint256[3] memory) {
        uint256[3] memory totalBalanceEachPhase;
        for (uint i=0; i < purchases[purchaser].length; i++) {
            totalBalanceEachPhase[i] = (purchases[purchaser][i] * bonusRates[i] / 100) + purchases[purchaser][i]; 
        }
        return totalBalanceEachPhase;
    }

   /**
     * @dev Returns the base amount of tokens purchased by a specific address.
     * @param purchaser The address to query the base purchased amount of.
     * @return The total base amount of tokens purchased by the specified address.
     */

    function getBasePurchasedAmount(address purchaser) public view returns (uint256) {
        uint256 totalAmount = 0;
        for (uint i = 0; i < purchases[purchaser].length; i++) {
            totalAmount += purchases[purchaser][i];
        }
        return totalAmount;
    }

    /**
     * @dev Returns the amount of tokens purchased by a specific address in a given phase.
     * @param purchaser The address to query the purchase amount of.
     * @param phase The phase to query the purchase amount in.
     * @return The amount of tokens purchased by the specified address in the given phase.
     */

    function getPurchasedAmountInPhase(address purchaser, uint8 phase) public view returns (uint256) {
        require (Phase(phase) == Phase.NotStarted && Phase(phase) == Phase.Ended, "Invalid Phase");
        return purchases[purchaser][(uint(phase) -1)];
    }

    /**
     * @dev Returns the start time of the ICO.
     * @return The timestamp of when the ICO started.
     */

    function getICOStartTime() public view returns (uint256) {
        return icoStartTime;
    }

    /**
     * @dev Internal function to update the end times of each phase based on their durations.
     * Used during the start of the ICO.
     */

    function updatePhaseEndTimes() internal {
        uint256 time = icoStartTime;
        for (uint8 i = 0; i < phaseDurations.length; i++) {
            time += phaseDurations[i];
            phaseEndTimes[i] = time;
        }
    }
}