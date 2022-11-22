////SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./interfaces/IBiswapFactory.sol";
import "./interfaces/IBiswapPair.sol";
import "./interfaces/ISwapFeeRewardWithRBOld.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IBiswapCollectiblesNFT.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract FeeRewardHelper is Initializable, OwnableUpgradeable {
    ISwapFeeRewardWithRBOld constant public feeRewardOld = ISwapFeeRewardWithRBOld(0x04eFD76283A70334C72BB4015e90D034B9F3d245);
    address constant public USDT = 0x55d398326f99059fF775485246999027B3197955;

    struct SwapInfo{
        uint amountOut;
        uint price;
        uint priceImpact;
        uint tradeFee;
        uint tradeFeeUSDT;
        uint feeReturn;
        uint feeReturnUSDT;
        uint rbAmount;
    }

    function calcAmounts(uint amount, address account) internal view returns (uint feeAmount, uint rbAmount) {
        feeAmount = amount * (feeRewardOld.defaultFeeDistribution() - feeRewardOld.feeDistribution(account))/100;
        rbAmount = amount - feeAmount;
    }

    function swapInfo(address account, address[] memory path, uint amountIn) public view returns(SwapInfo memory _swapInfo){
        require(path.length >= 2, 'FeeRewardHelper: INVALID_PATH');
        uint[] memory amountsOut = new uint[](path.length);

        amountsOut[0] = amountIn;
        _swapInfo.tradeFee = 1;
        uint reserve0;

        for (uint i; i < path.length - 1; i++) {
            IBiswapPair _pair = IBiswapPair(feeRewardOld.pairFor(path[i], path[i + 1]));
            uint _pairFee = 1000 - _pair.swapFee();
            (uint reserveIn, uint reserveOut,) = _pair.getReserves();
            (reserveIn, reserveOut) = _pair.token0() == path[i] ? (reserveIn, reserveOut) : (reserveOut, reserveIn);
            if (i == 0) reserve0 = reserveIn;
            amountsOut[i + 1] = getAmountOut(amountsOut[i], reserveIn, reserveOut, _pairFee);

            (uint _rbAmount, uint _feeReturn) = checkSwap(account, path[i], path[i + 1], amountsOut[i+1]);
            _swapInfo.rbAmount  += _rbAmount;
            _swapInfo.feeReturn += _feeReturn;
            _swapInfo.tradeFee  *= _pairFee;
        }
                                //1e18   -      1e18 *998 /
        _swapInfo.tradeFee = amountIn - amountIn * _swapInfo.tradeFee / (1000**(path.length-1));
        _swapInfo.tradeFeeUSDT = feeRewardOld.getQuantity(path[0], _swapInfo.tradeFee, USDT);
        _swapInfo.feeReturnUSDT = feeRewardOld.getQuantity(feeRewardOld.targetToken(), _swapInfo.feeReturn, USDT);
        _swapInfo.amountOut = amountsOut[path.length-1];
        _swapInfo.price = _swapInfo.amountOut * 1e12 / amountIn;


        uint amountInWithFee = amountIn - _swapInfo.tradeFee;
        _swapInfo.priceImpact = 1e12 * amountInWithFee / (reserve0 + amountInWithFee);

    }

        // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint swapFee) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'BiswapLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'BiswapLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * swapFee;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function checkSwap(
        address account,
        address input,
        address output,
        uint amount
    ) internal view returns (
        uint rbAmount,
        uint feeReturn
    ) {
        address pair = feeRewardOld.pairFor(input, output);
        uint pairFee = IBiswapPair(pair).swapFee();

        if (!feeRewardOld.isWhitelist(input) || !feeRewardOld.isWhitelist(output)) return(rbAmount, feeReturn);
        ISwapFeeRewardWithRBOld.PairsList memory pool = feeRewardOld.pairsList(feeRewardOld.pairOfPid(pair));
        if (pool.pair != pair || pool.enabled == false) return(rbAmount, feeReturn);

        (uint feeAmount, uint _rbAmount) = calcAmounts(amount, account);
//        uint fee = feeAmount * pairFee/ (1000 - pairFee);
        uint fee = feeAmount / (1000 - pairFee);
        rbAmount = feeRewardOld.getQuantity(output, _rbAmount, feeRewardOld.targetRBToken()) / feeRewardOld.rbWagerOnSwap();
        feeReturn = feeRewardOld.getQuantity(output, fee, feeRewardOld.targetToken()) * pool.percentReward / 100;
    }
}
