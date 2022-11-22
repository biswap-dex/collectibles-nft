//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ISquidPlayerNFT{
    struct TokensViewFront {
        uint tokenId;
        uint8 rarity;
        address tokenOwner;
        uint128 squidEnergy;
        uint128 maxSquidEnergy;
        uint32 contractEndTimestamp;
        uint32 contractV2EndTimestamp;
        uint32 busyTo; //Timestamp until which the player is busy
        uint32 createTimestamp;
        bool stakeFreeze;
        string uri;
        bool contractBought;
    }

    function getToken(uint _tokenId) external view returns (TokensViewFront memory);

    function arrayUserPlayers(address _user) external view returns (TokensViewFront[] memory);

    function balanceOf(address owner) external view returns (uint balance);

    function burnForCollectibles(address user, uint[] calldata tokenId) external returns(uint);
}
