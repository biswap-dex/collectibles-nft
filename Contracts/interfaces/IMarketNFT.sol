//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IMarketNFT {
    function tokenSellOffers(address nft, uint tokenId) external view returns(uint);
}
