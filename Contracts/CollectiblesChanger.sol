//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./interfaces/IBiswapNFT.sol";
import "./interfaces/ISquidPlayerNFT.sol";
import "./interfaces/ISquidBusNFT.sol";
import "./interfaces/IAutoBSW.sol";
import "./interfaces/IBiswapCollectiblesNFT.sol";
import "./interfaces/IMarketNFT.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract CollectiblesChanger is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    struct LevelRequirements {
        uint128 rb;
        uint128 se;
        uint8 busCap;
        uint8 quantityAvailable;
        uint8 quantitySold;
    }

    struct CollectiblesLevel {
        uint128 totalBurnedRB;
        uint128 totalBurnedSE;
        uint128 totalBurnedBusCap;
        LevelRequirements[5] prices; //initiate with sort min to max
    }

    IMarketNFT constant marketNFT = IMarketNFT(0x23567C7299702018B133ad63cE28685788ff3f67);

    IAutoBSW public holderPool;
    ISquidPlayerNFT public squidPlayerNFT;
    ISquidBusNFT public squidBusNFT;
    IBiswapNFT public biswapNFT;
    IBiswapCollectiblesNFT public biswapCollectibles;

    uint public minRequirementsHolderPool;

    CollectiblesLevel[] public collectiblesLevel; //levels start from zero

    event RBToCollectiblesChanged(uint128 totalRBForBurn);
    event SEToCollectiblesChanged(uint128 totalSEForBurn, uint128 totalBusCupBurn);


    //Initialize function ---------------------------------------------------------------------------------------------

    function initialize(
        uint _minRequirementsHolderPool,
        LevelRequirements[5][] calldata _levelRequirements,
        IAutoBSW _holderPool,
        ISquidPlayerNFT _squidPlayerNFT,
        ISquidBusNFT _squidBusNFT,
        IBiswapNFT _robiNFT,
        IBiswapCollectiblesNFT _biswapCollectibles
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        squidPlayerNFT = _squidPlayerNFT;
        holderPool = _holderPool;
        squidBusNFT = _squidBusNFT;
        biswapNFT = _robiNFT;
        biswapCollectibles = _biswapCollectibles;
        minRequirementsHolderPool = _minRequirementsHolderPool;
        for (uint i = 0; i < _levelRequirements.length; i++) {
            collectiblesLevel.push();
            for (uint j = 0; j < _levelRequirements[i].length; j++) {
                collectiblesLevel[collectiblesLevel.length - 1].prices[j] = _levelRequirements[i][j];
            }
        }
    }

    //Modifiers -------------------------------------------------------------------------------------------------------

    modifier notContract() {
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        require(msg.sender.code.length == 0, "Contract not allowed");
        _;
    }

    modifier holderPoolCheck() {
        uint autoBswBalance = (holderPool.balanceOf() * holderPool.userInfo(msg.sender).shares) /
            holderPool.totalShares();
        require(autoBswBalance >= minRequirementsHolderPool, "Need more stake in holder pool");
        _;
    }

    //External functions ----------------------------------------------------------------------------------------------

    function setAddresses(IAutoBSW _holderPool,
        ISquidPlayerNFT _squidPlayerNFT,
        ISquidBusNFT _squidBusNFT,
        IBiswapNFT _biswapNFT,
        IBiswapCollectiblesNFT _biswapCollectibles
    ) external onlyOwner {
        holderPool = _holderPool;
        squidPlayerNFT = _squidPlayerNFT;
        squidBusNFT = _squidBusNFT;
        biswapNFT = _biswapNFT;
        biswapCollectibles = _biswapCollectibles;
    }

    function changeToCollectiblesRB(uint[] calldata tokenIds, uint8 level)
        external
        whenNotPaused
        nonReentrant
        notContract
        holderPoolCheck
    {
        require(level <= collectiblesLevel.length, "Wrong level");
        (LevelRequirements memory currentLevelRequirement, uint priceIndex) = getCurrentLevelRequirement(level);
        require(currentLevelRequirement.rb > 0, "Level sold");
        uint128 totalRBForBurn = uint128(biswapNFT.burnForCollectibles(msg.sender, tokenIds));
        require(totalRBForBurn >= currentLevelRequirement.rb, "Not enough burned amount");
        CollectiblesLevel storage currentCollectLevel = collectiblesLevel[level - 1];
        currentCollectLevel.totalBurnedRB += totalRBForBurn;
        currentCollectLevel.prices[priceIndex].quantitySold += 1;
        biswapCollectibles.mint(msg.sender, level);
        emit RBToCollectiblesChanged(totalRBForBurn);
    }

    function changeToCollectiblesSE(
        uint[] calldata playersTokenId,
        uint[] calldata bussesTokenId,
        uint8 level
    ) external whenNotPaused nonReentrant notContract holderPoolCheck {
        require(level <= collectiblesLevel.length, "Wrong level");
        (LevelRequirements memory currentLevelRequirement, uint priceIndex) = getCurrentLevelRequirement(level);
        require(currentLevelRequirement.se > 0, "Level sold");
        uint128 totalSEForBurn = uint128(squidPlayerNFT.burnForCollectibles(msg.sender, playersTokenId));
        uint128 totalBusCapForBurn = uint128(squidBusNFT.burnForCollectibles(msg.sender, bussesTokenId));
        require(
            totalSEForBurn >= currentLevelRequirement.se && totalBusCapForBurn >= currentLevelRequirement.busCap,
            "not enough burned amount"
        );
        CollectiblesLevel storage currentCollectLevel = collectiblesLevel[level - 1];
        currentCollectLevel.totalBurnedSE += totalSEForBurn;
        currentCollectLevel.totalBurnedBusCap += totalBusCapForBurn;
        currentCollectLevel.prices[priceIndex].quantitySold += 1;
        biswapCollectibles.mint(msg.sender, level);
        emit SEToCollectiblesChanged(totalSEForBurn, totalBusCapForBurn);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getMarketOfferId(address nft, uint tokenId) public view returns(uint offerId){
        offerId = marketNFT.tokenSellOffers(nft, tokenId);
    }

    function getPlayerTokens(address user) external view returns (ISquidPlayerNFT.TokensViewFront[] memory nfts, bool[] memory hasSellOffer) {
        nfts = user == address(0) ? nfts : squidPlayerNFT.arrayUserPlayers(user);
        hasSellOffer = new bool[](nfts.length);
        for(uint i; i < nfts.length; i++){
            hasSellOffer[i] = getMarketOfferId(address(squidPlayerNFT), nfts[i].tokenId) != 0;
        }
    }

    function getBusTokens(address user) external view returns (ISquidBusNFT.BusToken[] memory nfts, bool[] memory hasSellOffer) {
        if (user != address(0)) {
            uint count = squidBusNFT.balanceOf(user);
            nfts = new ISquidBusNFT.BusToken[](count);
            hasSellOffer = new bool[](count);
            if (count > 0) {
                for (uint i = 0; i < count; i++) {
                    (uint tokenId, , uint8 level, uint32 createTimestamp, string memory uri) = squidBusNFT.getToken(
                        squidBusNFT.tokenOfOwnerByIndex(user, i)
                    );
                    nfts[i].tokenId = tokenId;
                    nfts[i].level = level;
                    nfts[i].createTimestamp = createTimestamp;
                    nfts[i].uri = uri;
                    hasSellOffer[i] = getMarketOfferId(address(squidBusNFT), tokenId) != 0;
                }
            }
        }
        return (nfts, hasSellOffer);
    }

    function getRobiTokens(address user) external view returns (IBiswapNFT.TokenView[] memory nfts, bool[] memory hasSellOffer) {
        if (user != address(0)) {
            uint count = biswapNFT.balanceOf(user);
            nfts = new IBiswapNFT.TokenView[](count);
            hasSellOffer = new bool[](count);
            for (uint i = 0; i < count; i++) {
                (
                    uint tokenId,
                    ,
                    uint level,
                    uint robiBoost,
                    bool stakeFreeze,
                    uint createTimestamp,
                    ,
                    string memory uri
                ) = biswapNFT.getToken(biswapNFT.tokenOfOwnerByIndex(user, i));
                nfts[i].tokenId = tokenId;
                nfts[i].level = level;
                nfts[i].robiBoost = robiBoost;
                nfts[i].stakeFreeze = stakeFreeze;
                nfts[i].createTimestamp = createTimestamp;
                nfts[i].uri = uri;
                hasSellOffer[i] = getMarketOfferId(address(biswapNFT), tokenId) != 0;
            }
        }
        return (nfts, hasSellOffer);
    }

    function getCollectiblesTokens(address user)
        external
        view
        returns (IBiswapCollectiblesNFT.TokenView[] memory nfts, bool[] memory hasSellOffer)
    {
        nfts = biswapCollectibles.getUserTokens(user);
        hasSellOffer = new bool[](nfts.length);
        for(uint i; i < nfts.length; i++){
            hasSellOffer[i] = getMarketOfferId(address(biswapCollectibles), nfts[i].tokenId) != 0;
        }
    }

    //Public functions ----------------------------------------------------------------------------------------------

    function getUserInfo(address user)
        public
        view
        returns (
            LevelRequirements[] memory currentLevelRequirements,
            uint robiNFTBalance,
            uint playersBalance,
            uint busBalance,
            uint totalRbinNFTs,
            uint AvailableRB,
            uint _minRequirementsHolderPool,
            uint holderPoolBalance
        )
    {
        currentLevelRequirements = new LevelRequirements[](collectiblesLevel.length);
        for (uint8 i = 0; i < collectiblesLevel.length; i++) {
            (currentLevelRequirements[i], ) = getCurrentLevelRequirement(i+1);
        }
        robiNFTBalance = biswapNFT.balanceOf(user);
        playersBalance = squidPlayerNFT.balanceOf(user);
        busBalance = squidBusNFT.balanceOf(user);
        AvailableRB = biswapNFT.getRbBalance(user);
        _minRequirementsHolderPool = minRequirementsHolderPool;
        totalRbinNFTs = 0;
        for(uint i = 0; i < robiNFTBalance; i++){
            totalRbinNFTs += biswapNFT.getRB(biswapNFT.tokenOfOwnerByIndex(user, i));
        }
        holderPoolBalance = (holderPool.balanceOf() * holderPool.userInfo(user).shares) /
        holderPool.totalShares();
    }

    //Internal functions --------------------------------------------------------------------------------------------
    function getCurrentLevelRequirement(uint8 level)
        internal
        view
        returns (LevelRequirements memory currentLevelRequirement, uint priceIndex)
    {
        require(level > 0 && level <= collectiblesLevel.length, 'Wrong level');
        CollectiblesLevel memory currentLevel = collectiblesLevel[level - 1];
        for (uint i = 0; i < currentLevel.prices.length; i++) {
            if (currentLevel.prices[i].quantityAvailable > currentLevel.prices[i].quantitySold) {
                return (currentLevel.prices[i], i);
            }
        }
        return (currentLevelRequirement, priceIndex);
    }

    //Private functions ---------------------------------------------------------------------------------------------
}
