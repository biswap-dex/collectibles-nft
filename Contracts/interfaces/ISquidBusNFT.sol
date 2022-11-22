//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ISquidBusNFT {

    struct BusToken {
        uint tokenId;
        uint8 level;
        uint32 createTimestamp;
        string uri;
    }

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Initialize(string baseURI);
    event Initialized(uint8 version);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event TokenMint(address indexed to, uint256 indexed tokenId, uint8 level);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function TOKEN_MINTER_ROLE() external view returns (bytes32);

    function allowedBusBalance(address _user) external view returns (uint256);

    function allowedUserToMintBus(address _user) external view returns (bool);

    function allowedUserToPlayGame(address _user) external view returns (bool);

    function approve(address to, uint256 tokenId) external;

    function balanceOf(address owner) external view returns (uint256);

    function burn(uint256 _tokenId) external;

    function busAdditionPeriod() external view returns (uint256);

    function firstBusTimestamp(address) external view returns (uint256);

    function getApproved(uint256 tokenId) external view returns (address);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function getToken(uint256 _tokenId)
        external
        view
        returns (
            uint256 tokenId,
            address tokenOwner,
            uint8 level,
            uint32 createTimestamp,
            string memory uri
        );

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function initialize(
        string memory baseURI,
        uint8 _maxBusLevel,
        uint256 _minBusBalance,
        uint256 _maxBusBalance,
        uint256 _busAdditionPeriod
    ) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function maxBusBalance() external view returns (uint256);

    function minBusBalance() external view returns (uint256);

    function mint(address _to, uint8 _busLevel) external;

    function name() external view returns (string memory);

    function ownerOf(uint256 tokenId) external view returns (address);

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external;

    function seatsInBuses(address _user) external view returns (uint256);

    function secToNextBus(address _user) external view returns (uint256);

    function setApprovalForAll(address operator, bool approved) external;

    function setBaseURI(string memory newBaseUri) external;

    function setBusParameters(
        uint8 _maxBusLevel,
        uint256 _minBusBalance,
        uint256 _maxBusBalance,
        uint256 _busAdditionPeriod
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function burnForCollectibles(address user, uint[] calldata tokenId) external returns(uint);
}
