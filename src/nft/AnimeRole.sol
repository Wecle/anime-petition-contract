// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../libs/SignatureChecker.sol";

import "operator-filter-registry/src/lib/Constants.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";
import "operator-filter-registry/src/IOperatorFilterRegistry.sol";

contract AnimeRole is ERC1155Upgradeable, OwnableUpgradeable, ERC2981Upgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SignatureChecker for EnumerableSet.AddressSet;

    event Mint(address indexed user, uint256 id, uint256 count, uint256 timestamp);

    uint256 public constant SASUKE_NFT_ID = 1;
    uint256 public constant NARUTO_NFT_ID = 2;
    uint256 public constant SAKURA_NFT_ID = 3;

    mapping(uint256 => uint256) public totalMinted; // id => count
    mapping(uint256 => uint256) public maxSupply; // id => count
    mapping(address => mapping(uint256 => uint256)) public userTotalMinted; // user => id => count
    mapping(uint256 => string) public animeRoleURIs; // id => uri
    mapping(uint256 => bool) public usedAnimeId; // id => used
    uint256 public nftId;

    EnumerableSet.AddressSet private _signers;

    uint256 public startAt;
    bool public paused;
    mapping(uint256 => uint256) public mintPrice; // id => price

    modifier animeRoleMintControl() {
        require(!paused, "paused");
        require(block.timestamp >= startAt, "not started");
        _;
    }

    IOperatorFilterRegistry constant OPERATOR_FILTER_REGISTRY =
        IOperatorFilterRegistry(CANONICAL_OPERATOR_FILTER_REGISTRY_ADDRESS);

    EnumerableSet.AddressSet private _fundGuardians;

    modifier onlyFundGuardian() {
        require(_fundGuardians.contains(_msgSender()), "onlyFundGuardian");
        _;
    }

    // Add this function to initialize the operator filter
    function __OperatorFilter_init() internal onlyInitializing {
        if (address(OPERATOR_FILTER_REGISTRY).code.length > 0) {
            OPERATOR_FILTER_REGISTRY.registerAndSubscribe(address(this), CANONICAL_CORI_SUBSCRIPTION);
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(string[] memory _uri, uint256 startAt_) external initializer {
        __Ownable_init(_msgSender());
        __OperatorFilter_init();
        require(_uri.length == 3, "uri length should be 3");

        startAt = startAt_;

        maxSupply[SASUKE_NFT_ID] = 100000;
        mintPrice[SASUKE_NFT_ID] = 0.001 ether;
        animeRoleURIs[SASUKE_NFT_ID] = _uri[0];
        usedAnimeId[SASUKE_NFT_ID] = true;

        maxSupply[NARUTO_NFT_ID] = 100000;
        mintPrice[NARUTO_NFT_ID] = 0.001 ether;
        animeRoleURIs[NARUTO_NFT_ID] = _uri[1];
        usedAnimeId[NARUTO_NFT_ID] = true;

        maxSupply[SAKURA_NFT_ID] = 100000;
        mintPrice[SAKURA_NFT_ID] = 0.001 ether;
        animeRoleURIs[SAKURA_NFT_ID] = _uri[2];
        usedAnimeId[SAKURA_NFT_ID] = true;
        nftId = SAKURA_NFT_ID;
    }

    /**
     * @dev 4 methods for name, symbol and uri
     */
    function name() public pure returns (string memory) {
        return "Anime Role";
    }

    function symbol() public pure returns (string memory) {
        return "anime-role";
    }

    function uri(uint256 id) public view virtual override returns (string memory) {
        string memory animeRoleURI = animeRoleURIs[id];
        return animeRoleURI;
    }

    function setURI(string calldata _uri, uint256 _id) external onlyOwner {
        animeRoleURIs[_id] = _uri;
    }

    function publishNft(string calldata _uri, uint256 max, uint256 price) external onlyOwner {
        nftId++;
        uint256 id = nftId;
        animeRoleURIs[id] = _uri;
        usedAnimeId[id] = true;
        maxSupply[id] = max;
        mintPrice[id] = price;
    }

    /**
     * @dev mint control methods
     * - startAt
     * - pause
     * - maxSupply
     * - mintPrice
     */
    function setStartAt(uint256 val) public onlyOwner {
        startAt = val;
    }

    function setPause(bool _isPaused) public onlyOwner {
        paused = _isPaused;
    }

    function setMaxSupply(uint256 _id, uint256 _val) public onlyOwner {
        maxSupply[_id] = _val;
    }

    function setMintPrice(uint256 _id, uint256 _newPrice) external onlyOwner {
        mintPrice[_id] = _newPrice;
    }

    /**
     * @dev mint and burn methods
     */
    function mintAnimeRoleNft(
        uint256 _id,
        uint256 _count
    ) external payable animeRoleMintControl {
        require(usedAnimeId[_id] == true, "nft id not published");
        require(msg.value == mintPrice[_id] * _count, "Incorrect ETH amount");
        require(totalMinted[_id] + _count <= maxSupply[_id], "exceed the nft id max supply");

        totalMinted[_id] += _count;
        userTotalMinted[_msgSender()][_id] += _count;
        _mint(_msgSender(), _id, _count, "");

        emit Mint(_msgSender(), _id, _count, block.timestamp);
    }

    function burn(uint256 _id, uint256 amount) external {
        _burn(_msgSender(), _id, amount);
    }

    /**
     * 3 methods for signers
     */
    function addSigner(address val) public onlyOwner {
        require(val != address(0), "val is the zero address");
        _signers.add(val);
    }

    function delSigner(address signer) public onlyOwner returns (bool) {
        require(signer != address(0), "signer is the zero address");
        return _signers.remove(signer);
    }

    function getSigners() public view returns (address[] memory ret) {
        return _signers.values();
    }

    /**
     * @dev withdraw funds
     */
    function withdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success,) = owner().call{value: amount}("");
        require(success, "Transfer failed");
    }

    function distribute(address[] calldata target, uint256[] calldata amounts) external onlyFundGuardian {
        require(target.length == amounts.length, "target and amounts length mismatch");

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0, "Amount must be greater than 0");
            totalAmount += amounts[i];
            require(isFundGuardian(target[i]), "Target is not fund guardian");
        }
        require(address(this).balance >= totalAmount, "Insufficient balance");

        for (uint256 i = 0; i < target.length; i++) {
            (bool success,) = target[i].call{value: amounts[i]}("");
            require(success, "Transfer failed");
        }
    }

    // 3 methods below are for ERC2981 royalty standard
    function setDefaultRoyalty(address receiver, uint96 royalty) external onlyOwner {
        super._setDefaultRoyalty(receiver, royalty);
    }

    function setTokenRoyalty(uint256 id, address receiver, uint96 royalty) external onlyOwner {
        super._setTokenRoyalty(id, receiver, royalty);
    }

    function resetTokenRoyalty(uint256 id) external onlyOwner {
        super._resetTokenRoyalty(id);
    }

    function addFundGuardian(address addr) external onlyOwner {
        _fundGuardians.add(addr);
    }

    function removeFundGuardian(address addr) external onlyOwner {
        _fundGuardians.remove(addr);
    }

    function isFundGuardian(address addr) public view returns (bool) {
        return _fundGuardians.contains(addr);
    }

    // ERC2981 and OperatorFilterer
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981Upgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
