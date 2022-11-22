//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ISwapFeeRewardWithRBOld {

    struct PairsList {
        address pair;
        uint256 percentReward;
        bool enabled;
    }

    function getQuantity(
        address outputToken,
        uint256 outputAmount,
        address anchorToken
    ) external view returns (uint256);

    function pairFor(address tokenA, address tokenB) external view returns (address pair);
    function defaultFeeDistribution() external view returns(uint);
    function rbWagerOnSwap() external view returns(uint);
    function targetToken() external view returns(address);
    function targetRBToken() external view returns(address);
    function pairOfPid(address) external view returns(uint);
    function isWhitelist(address _token) external view returns (bool);
    function pairsList(uint) external view returns(PairsList memory);
    function feeDistribution(address) external view returns(uint);
    function rewardBalance(address account) external view returns (uint);
}
