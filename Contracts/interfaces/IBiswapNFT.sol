//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IBiswapNFT {
    struct Token {
        uint robiBoost;
        uint level;
        bool stakeFreeze;
        uint createTimestamp;
    }

    struct TokenView {
        uint tokenId;
        uint robiBoost;
        uint level;
        bool stakeFreeze;
        uint createTimestamp;
        string uri;
    }

    function getLevel(uint tokenId) external view returns (uint);

    function getRB(uint tokenId) external view returns (uint);

    function getInfoForStaking(uint tokenId)
        external
        view
        returns (
            address tokenOwner,
            bool stakeFreeze,
            uint robiBoost
        );

    function getToken(uint _tokenId)
        external
        view
        returns (
            uint tokenId,
            address tokenOwner,
            uint level,
            uint rb,
            bool stakeFreeze,
            uint createTimestamp,
            uint remainToNextLevel,
            string memory uri
        );

    function accrueRB(address user, uint amount) external;

    function tokenFreeze(uint tokenId) external;

    function tokenUnfreeze(uint tokenId) external;

    function balanceOf(address owner) external view returns (uint256);

    function getRbBalance(address user) external view returns (uint);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    function burnForCollectibles(address user, uint[] calldata tokenId) external returns (uint); //todo add in contract returns RB amount
}
