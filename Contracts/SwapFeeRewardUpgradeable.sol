//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interfaces/IBiswapNFT.sol";
import "./interfaces/IBiswapFactory.sol";
import "./interfaces/IBiswapPair.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IBiswapCollectiblesNFT.sol";
import "./interfaces/ISwapFeeRewardWithRBOld.sol";

contract SwapFeeRewardUpgradeable is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    struct TokensPath {
        address output;
        address anchor;
        address intermediate;
    }

    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    uint public constant maxMiningAmount = 100000000 ether; //todo reduce by already minted amount???
    uint public constant maxMiningInPhase = 5000 ether;
    uint public constant maxAccruedRBInPhase = 5000 ether;
    uint public constant defaultFeeDistribution = 90;
    address public constant factory = 0x858E3312ed3A876947EA49d572A7C42DE08af7EE;

    address public router;
    address public market;
    address public auction;

    uint public currentPhase;
    uint public currentPhaseRB;
    uint public totalMined;
    uint public totalAccruedRB;
    uint public rbWagerOnSwap; //Wager of RB
    uint public rbPercentMarket; // (div 10000)
    uint public rbPercentAuction; // (div 10000)
    address public targetToken;
    address public targetRBToken;

    IERC20Upgradeable public bswToken;
    IOracle public oracle;
    IBiswapNFT public biswapNFT;
    IBiswapCollectiblesNFT public collectiblesNFT;
    ISwapFeeRewardWithRBOld public constant oldSwapFeeReward =
        ISwapFeeRewardWithRBOld(0x04eFD76283A70334C72BB4015e90D034B9F3d245);

    mapping(address => uint) public nonces;
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => address)) public intermediateToken; //intermediate tokens: output token =>  anchorToken => intermediate; if intermediate == 0 direct pair

    mapping(address => mapping(uint => uint)) public tradeVolume; //trade amount userAddress => day => accumulated amount
    mapping(uint => mapping(uint => uint)) public cashbackVolumeByMonth; //Accrue cashback by tokenId by month
    //percent of distribution between feeReward and robiBoost [0, 90] 0 => 90% feeReward and 10% robiBoost; 90 => 100% robiBoost
    //calculate: defaultFeeDistribution (90) - feeDistibution = feeReward

    mapping(address => uint) public percentReward; //percent reward: pair address => percent (base 100)

    struct Cashback {
        uint16 percent;
        uint128 monthlyLimit;
    }

    Cashback[] public cashbackPercent; // Cashback percent base 10000 index = level - 1
    address[] public pairsList; //list of pairs with reward

    event Withdraw(address userAddress, uint amount);
    event Rewarded(address account, address input, address output, uint amount, uint quantity);
    event NewRouter(address);
    event NewFactory(address);
    event NewMarket(address);
    event NewPhase(uint);
    event NewPhaseRB(uint);
    event NewAuction(address);
    event NewBiswapNFT(IBiswapNFT);
    event NewOracle(IOracle);
    event CashbackRewarded(
        uint tokenId,
        uint rewardAmount,
        uint currentMounth,
        uint accumulatedCashbackByMonth,
        uint balance
    );
    event WithdrawCashback(address user, uint amount, uint[] tokensId);
    event IntermediateTokenSet(TokensPath[]);
    event IntermediateTokenNotAdded(TokensPath);
    event NewCashbackPercent(Cashback[]);

    modifier onlyRouter() {
        require(msg.sender == router, "SwapFeeReward: only router");
        _;
    }

    modifier onlyMarket() {
        require(msg.sender == market, "SwapFeeReward: only market");
        _;
    }

    modifier onlyAuction() {
        require(msg.sender == auction, "SwapFeeReward: only auction");
        _;
    }

    function initialize(
        address _router,
        IERC20Upgradeable _bswToken,
        IOracle _Oracle,
        IBiswapNFT _biswapNFT,
        IBiswapCollectiblesNFT _collectiblesNFT,
        address _targetToken,
        address _targetRBToken,
        Cashback[] calldata _cashbackPercent,
        address _market,
        address _auction
    ) public initializer {
        require(
            _router != address(0) && _targetToken != address(0) && _targetRBToken != address(0),
            "Address can not be zero"
        );
        __ReentrancyGuard_init();
        __Ownable_init();

        router = _router;
        bswToken = _bswToken;
        oracle = _Oracle;
        biswapNFT = _biswapNFT;
        collectiblesNFT = _collectiblesNFT;
        targetToken = _targetToken;
        targetRBToken = _targetRBToken;
        market = _market;
        auction = _auction;

        currentPhase = 1;
        currentPhaseRB = 1;
        rbWagerOnSwap = 1500;
        rbPercentMarket = 2222;
        rbPercentAuction = 2222;

        setCashbackPercent(_cashbackPercent);
    }

    function getCurrentMonth() public view returns (uint month) {
        month = block.timestamp / 30 days;
    }

    function setMarket(address _market) public onlyOwner{
        require(_market != address(0), 'SwapFeeReward: address cannot be zero');
        market = _market;
    }

    function setAuction(address _auction) public onlyOwner{
        require(_auction != address(0), 'SwapFeeReward: address cannot be zero');
        auction = _auction;
    }

    function setCashbackPercent(Cashback[] calldata newCashbackPercent) public onlyOwner {
        require(newCashbackPercent.length == collectiblesNFT.MAX_LEVEL(), "Wrong array size");
        delete cashbackPercent;
        for (uint i; i < newCashbackPercent.length; i++) {
            cashbackPercent.push(newCashbackPercent[i]);
        }
        emit NewCashbackPercent(newCashbackPercent);
    }

    function setIntermediateToken(TokensPath[] calldata tokens) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i].anchor != tokens[i].intermediate) {
                intermediateToken[tokens[i].output][tokens[i].anchor] = tokens[i].intermediate;
            } else {
                emit IntermediateTokenNotAdded(tokens[i]);
            }
        }
        emit IntermediateTokenSet(tokens);
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ZERO_ADDRESS");
    }

    function pairFor(address tokenA, address tokenB) public pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"fea293c909d87cd4153593f077b76bb7e94340200f4ee84211ae8e4f9bd7ffdf"
                        )
                    )
                )
            )
        );
    }

    function getSwapFee(address tokenA, address tokenB) internal view returns (uint swapFee) {
        swapFee = IBiswapPair(pairFor(tokenA, tokenB)).swapFee();
    }

    function setPhase(uint _newPhase) public onlyOwner returns (bool) {
        currentPhase = _newPhase;
        emit NewPhase(_newPhase);
        return true;
    }

    function setPhaseRB(uint _newPhase) public onlyOwner returns (bool) {
        currentPhaseRB = _newPhase;
        emit NewPhaseRB(_newPhase);
        return true;
    }

    function checkPairExist(address tokenA, address tokenB) public view returns (bool) {
        address pair = pairFor(tokenA, tokenB);
        return percentReward[pair] > 0;
    }

    struct SwapData {
        uint feeReturnAmount;
        uint rbAccrueAmount;
        uint cashBackAmount;
        uint selectedTokenId;
        uint amountOutInTargetRBToken;
        address pair;
        uint pairFee;
    }

    struct SwapInfo {
        uint amountOut;
        uint price;
        uint priceImpact;
        uint tradeFee;
        uint tradeFeeUSDT;
        uint feeReturn;
        uint feeReturnUSDT;
        uint rbAmount;
    }

    function getFeeDistribution(address account) public view returns (uint feeDistr) {
//        feeDistr = defaultFeeDistribution - oldSwapFeeReward.feeDistribution(account);
        return 100; // BSW-3734
    }

    function swapInfo(
        address account,
        address[] memory path,
        uint amountIn
    ) public view returns (SwapInfo memory _swapInfo) {
        require(path.length >= 2, "FeeRewardHelper: INVALID_PATH");
        uint[] memory amountsOut = new uint[](path.length);

        amountsOut[0] = amountIn;
        _swapInfo.tradeFee = 1;
        uint reserve0;

        uint feeDistr = getFeeDistribution(account);

        for (uint i; i < path.length - 1; i++) {
            IBiswapPair _pair = IBiswapPair(pairFor(path[i], path[i + 1]));
            uint _pairFee = 1000 - _pair.swapFee();
            (uint reserveIn, uint reserveOut, ) = _pair.getReserves();
            (reserveIn, reserveOut) = _pair.token0() == path[i] ? (reserveIn, reserveOut) : (reserveOut, reserveIn);
            if (i == 0) reserve0 = reserveIn;
            amountsOut[i + 1] = getAmountOut(amountsOut[i], reserveIn, reserveOut, _pairFee);

            SwapData memory swapData = calcSwap(account, feeDistr, path[i], path[i + 1], amountsOut[i + 1]);
            _swapInfo.rbAmount += swapData.rbAccrueAmount;
            _swapInfo.feeReturn += swapData.feeReturnAmount;
            _swapInfo.tradeFee *= _pairFee;
        }
        //1e18   -      1e18 *998 /
        _swapInfo.tradeFee = amountIn - (amountIn * _swapInfo.tradeFee) / (1000**(path.length - 1));
        _swapInfo.tradeFeeUSDT = getQuantity(path[0], _swapInfo.tradeFee, USDT);
        _swapInfo.feeReturnUSDT = getQuantity(targetToken, _swapInfo.feeReturn, USDT);
        _swapInfo.amountOut = amountsOut[path.length - 1];
        _swapInfo.price = (_swapInfo.amountOut * 1e12) / amountIn;

        uint amountInWithFee = amountIn - _swapInfo.tradeFee;
        _swapInfo.priceImpact = (1e12 * amountInWithFee) / (reserve0 + amountInWithFee);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut,
        uint swapFee
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint amountInWithFee = amountIn * swapFee;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function swap(
        address account,
        address input,
        address output,
        uint amountOut
    ) public onlyRouter returns (bool) {
        SwapData memory swapData = calcSwap(account, getFeeDistribution(account), input, output, amountOut);
        if (swapData.feeReturnAmount == 0 && swapData.rbAccrueAmount == 0) return false;

        //Accrue RB
        if (swapData.rbAccrueAmount > 0 && address(biswapNFT) != address(0)) {
            if (totalAccruedRB + swapData.rbAccrueAmount <= currentPhaseRB * maxAccruedRBInPhase) {
                totalAccruedRB += swapData.rbAccrueAmount;
                biswapNFT.accrueRB(account, swapData.rbAccrueAmount); //event emitted from BiswapNFT
            }
        }

        uint _totalMined = totalMined;

        //Accrue cashback
        if(maxMiningAmount >= _totalMined + swapData.cashBackAmount){
            if (_totalMined + swapData.cashBackAmount <= currentPhase * maxMiningInPhase) {
                if (swapData.selectedTokenId != 0 && swapData.cashBackAmount != 0) {
                    _balances[address(uint160(swapData.selectedTokenId))] += swapData.cashBackAmount;
                    uint curMonth = getCurrentMonth();
                    cashbackVolumeByMonth[swapData.selectedTokenId][curMonth] += swapData.cashBackAmount;
                    emit CashbackRewarded(
                        swapData.selectedTokenId,
                        swapData.cashBackAmount,
                        curMonth,
                        cashbackVolumeByMonth[swapData.selectedTokenId][curMonth],
                        _balances[address(uint160(swapData.selectedTokenId))]
                    );
                }
            }
        }

        //Accrue fee return
        if (maxMiningAmount >= _totalMined + swapData.feeReturnAmount) {
            if (_totalMined + swapData.feeReturnAmount <= currentPhase * maxMiningInPhase) {
                _balances[account] += swapData.feeReturnAmount;
                emit Rewarded(account, input, output, amountOut, swapData.feeReturnAmount);
            }
        }

        //Save trade volume
        if (swapData.amountOutInTargetRBToken != 0) {
            tradeVolume[account][block.timestamp / 1 days] += swapData.amountOutInTargetRBToken;
        }

        return true;
    }

    function calcSwap(
        address account,
        uint feeDistr,
        address input,
        address output,
        uint amountOut
    ) public view returns (SwapData memory swapData) {
        swapData.pair = pairFor(input, output);
        uint _percentReward = percentReward[swapData.pair];
        if (_percentReward == 0) {
            return swapData;
        }
        swapData.pairFee = IBiswapPair(swapData.pair).swapFee();
        swapData.amountOutInTargetRBToken = getQuantity(output, amountOut, targetRBToken);
        uint amountOutInTargetToken = getQuantity(output, amountOut, targetToken);
        if(swapData.amountOutInTargetRBToken == 0 && amountOutInTargetToken == 0) return swapData;
        swapData.rbAccrueAmount = (swapData.amountOutInTargetRBToken * (100 - feeDistr)) / (100 * rbWagerOnSwap);

        swapData.feeReturnAmount =
            (((amountOutInTargetToken * swapData.pairFee) / (1000 - swapData.pairFee)) * _percentReward * feeDistr) /
            10000;
        uint8 level;
        (swapData.selectedTokenId, level) = collectiblesNFT.getUserSelectedTokenId(account);
        if (swapData.selectedTokenId != 0 && account.code.length == 0) {
            Cashback memory currCashBack = cashbackPercent[level - 1];
            swapData.cashBackAmount =
                (((amountOutInTargetToken * swapData.pairFee) / (1000 - swapData.pairFee)) * currCashBack.percent) /
                10000;
            if (
                cashbackVolumeByMonth[swapData.selectedTokenId][getCurrentMonth()] + swapData.cashBackAmount >
                currCashBack.monthlyLimit
            ) {
                swapData.cashBackAmount =
                    currCashBack.monthlyLimit -
                    cashbackVolumeByMonth[swapData.selectedTokenId][getCurrentMonth()];
            }
        }
        return swapData;
    }


    function userTradeVolume(
        address user,
        uint firstDay,
        uint lastDay
    ) public view returns (uint[] memory volumes) {
        require(lastDay >= firstDay, "last day must be egt firstDay");
        volumes = new uint[](lastDay - firstDay + 1);
        for (uint i; i < lastDay - firstDay + 1; i++) {
            volumes[i] = tradeVolume[user][firstDay + i];
        }
    }

    function accrueRBFromMarket(
        address account,
        address fromToken,
        uint amount
    ) public onlyMarket {
        amount = (amount * rbPercentMarket) / 10000;
        _accrueRB(account, fromToken, amount);
    }

    function accrueRBFromAuction(
        address account,
        address fromToken,
        uint amount
    ) public onlyAuction {
        amount = (amount * rbPercentAuction) / 10000;
        _accrueRB(account, fromToken, amount);
    }

    function _accrueRB(
        address account,
        address output,
        uint amount
    ) private {
        uint quantity = getQuantity(output, amount, targetRBToken);
        if (quantity > 0) {
            totalAccruedRB = totalAccruedRB + quantity;
            if (totalAccruedRB <= currentPhaseRB * maxAccruedRBInPhase) {
                biswapNFT.accrueRB(account, quantity);
            }
        }
    }

    function rewardBalance(address account) public view returns (uint) {
        return _balances[account];
    }

    function rewardTokenBalance(uint tokenId) public view returns (uint) {
        return _balances[address(uint160(tokenId))];
    }

    function getUserCashbackBalances(address user)
        public
        view
        returns (uint[] memory tokensId, uint[] memory balances)
    {
        uint nftBalances = collectiblesNFT.balanceOf(user);
        tokensId = new uint[](nftBalances);
        balances = new uint[](nftBalances);
        for (uint i = 0; i < nftBalances; i++) {
            tokensId[i] = collectiblesNFT.tokenOfOwnerByIndex(user, i);
            balances[i] = _balances[address(uint160(tokensId[i]))];
        }
    }

    function permit(
        address spender,
        uint value,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private {
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(spender, value, nonces[spender]++))
            )
        );
        address recoveredAddress = ecrecover(message, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == spender, "SwapFeeReward: INVALID_SIGNATURE");
    }

    function withdrawCashback(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant returns (bool) {
        require(maxMiningAmount > totalMined, "SwapFeeReward: Mined all tokens");
        (uint[] memory tokensId, uint[] memory balances) = getUserCashbackBalances(msg.sender);
        uint balance;
        for(uint i = 0; i < balances.length; i++){
            delete _balances[address(uint160(tokensId[i]))];
            balance += balances[i];
        }
        require(
            totalMined + balance <= currentPhase * maxMiningInPhase,
            "SwapFeeReward: Mined all tokens in this phase"
        );
        permit(msg.sender, balance, v, r, s);
        if (balance > 0) {
            totalMined += balance;
            if (bswToken.transfer(msg.sender, balance)) {
                emit WithdrawCashback(msg.sender, balance, tokensId);
                return true;
            }
        }
        return false;
    }

    function withdraw(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant returns (bool) {
        require(maxMiningAmount > totalMined, "SwapFeeReward: Mined all tokens");
        uint balance = _balances[msg.sender];
        require(
            totalMined + balance <= currentPhase * maxMiningInPhase,
            "SwapFeeReward: Mined all tokens in this phase"
        );
        permit(msg.sender, balance, v, r, s);
        if (balance > 0) {
            _balances[msg.sender] -= balance;
            totalMined += balance;
            if (bswToken.transfer(msg.sender, balance)) {
                emit Withdraw(msg.sender, balance);
                return true;
            }
        }
        return false;
    }

    function getQuantity(
        address outputToken,
        uint outputAmount,
        address anchorToken
    ) public view returns (uint) {
        uint quantity = 0;
        if (outputToken == anchorToken) {
            quantity = outputAmount;
        } else {
            address intermediate = intermediateToken[outputToken][anchorToken];
            if (intermediate == address(0)) {
                quantity = 0;
            } else if (intermediate == outputToken) {
                quantity = IOracle(oracle).consult(intermediate, outputAmount, anchorToken);
            } else {
                uint interQuantity = IOracle(oracle).consult(outputToken, outputAmount, intermediate);
                quantity = IOracle(oracle).consult(intermediate, interQuantity, anchorToken);
            }
        }
        //
        return quantity;
    }

    function setOracle(IOracle _oracle) public onlyOwner {
        require(address(_oracle) != address(0), "SwapMining: new oracle is the zero address");
        oracle = _oracle;
        emit NewOracle(_oracle);
    }

    function setRouter(address _router) public onlyOwner {
        require(address(_router) != address(0), "SwapMining: new router is the zero address");
        router = _router;
    }

    function pairsListLength() public view returns (uint) {
        return pairsList.length;
    }

    function setPairs(uint[] calldata _percentReward, address[] calldata _pair) public onlyOwner {
        require(_percentReward.length == _pair.length, "Wrong arrays length");

        for (uint i; i < _pair.length; i++) {
            require(_pair[i] != address(0), "_pair is the zero address");
            require(_percentReward[i] <= 100 && _percentReward[i] > 0, "Wrong percent reward");
            if (percentReward[_pair[i]] == 0) pairsList.push(_pair[i]);
            percentReward[_pair[i]] = _percentReward[i];
        }
    }

    function delPairFromList(address pair, uint pid) public onlyOwner {
        address[] memory _pairsList = pairsList;
        require(pid < _pairsList.length, "pid out of bound");
        delete percentReward[pair];
        if (_pairsList[pid] != pair) {
            for (uint i; i < _pairsList.length; i++) {
                if (_pairsList[i] == pair) {
                    pairsList[i] = pairsList[pairsList.length - 1];
                    pairsList.pop();
                    return;
                }
            }
        } else {
            pairsList[pid] = pairsList[pairsList.length - 1];
            pairsList.pop();
        }
    }

    function setRobiBoostReward(
        uint _rbWagerOnSwap,
        uint _percentMarket,
        uint _percentAuction
    ) public onlyOwner {
        rbWagerOnSwap = _rbWagerOnSwap;
        rbPercentMarket = _percentMarket;
        rbPercentAuction = _percentAuction;
    }

    //  Use OLD FeeReward contract value
    //    function setFeeDistribution(uint newDistribution) public {
    //        require(newDistribution <= defaultFeeDistribution, "Wrong fee distribution");
    //        feeDistribution[msg.sender] = newDistribution;
    //        _newDistribution = newDistribution;
    //    }
}
