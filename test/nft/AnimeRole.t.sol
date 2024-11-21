// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {AnimeRole} from "../../src/nft/AnimeRole.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract AnimeRoleTest is Test {
    AnimeRole animeRole;
    AnimeRole animeRoleWithDefinedOwner;

    uint256 public currentTs;
    uint256 public animeRoleSignerPvKey = 0x1234;

    address public caller = address(0x100);
    address public proxyAdmin = address(0x9876);
    address public definedOwner = address(0x300);

    uint256 public maxSupply = 100000;
    uint256 public mintCost = 0.001 ether;
    string public sasuke_uri = "https://animeRole.io/1";
    string public naruto_uri = "https://animeRole.io/2";
    string public sakura_uri = "https://animeRole.io/3";

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        currentTs = vm.getBlockTimestamp();
        vm.deal(proxyAdmin, 10000 ether);

        animeRole = AnimeRole(deployAnimeRole(address(this)));

        animeRole.addSigner(vm.addr(animeRoleSignerPvKey));

        vm.deal(caller, 10000 ether);

        // set up another contract with defined owner

        vm.deal(definedOwner, 10000 ether);
        animeRoleWithDefinedOwner = AnimeRole(deployAnimeRole(definedOwner));
        console.log("animeRoleWithDefinedOwner address: ", address(animeRoleWithDefinedOwner));
        console.log("definedOwner address: ", definedOwner);
    }

    function deployAnimeRole(address owner) internal returns (address) {
        vm.startPrank(owner);
        console.log("deployAnimeRole, address: ", msg.sender);
        string[] memory uri = new string[](3);
        uri[0] = sasuke_uri;
        uri[1] = naruto_uri;
        uri[2] = sakura_uri;
        address proxy = Upgrades.deployTransparentProxy(
            "AnimeRole.sol",
            proxyAdmin,
            abi.encodeCall(AnimeRole.initialize, (uri, currentTs + 1 days))
        );
        vm.stopPrank();
        return proxy;
    }

    function test_init() public view {
        assertEq(animeRole.uri(1), sasuke_uri);
        assertEq(animeRole.uri(2), naruto_uri);
        assertEq(animeRole.uri(3), sakura_uri);
        assertEq(animeRole.uri(4), "");

        // some hardcoded values we need to fix before launch
        assertEq(animeRole.name(), "Anime Role");
        assertEq(animeRole.symbol(), "anime-role");
        assertEq(animeRole.maxSupply(1), maxSupply);
        assertEq(animeRole.maxSupply(2), maxSupply);
        assertEq(animeRole.maxSupply(3), maxSupply);
        assertEq(animeRole.maxSupply(4), 0);
    }

    function test_mint_happycase_simple(uint256 num) public {
        num = bound(num, 1, animeRole.maxSupply(1));
        uint32 mintNum = SafeCast.toUint32(num);
        uint32 mintId = 1;

        vm.warp(block.timestamp + 1 days + 1 minutes);

        console.log("test_mint_happycase_simple, caller balance before: ", address(caller).balance);
        uint256 cntBalanceBefore = address(animeRole).balance;
        vm.startPrank(caller);
        animeRole.mintAnimeRoleNft{value: mintNum * mintCost}(mintId, mintNum);
        vm.stopPrank();
        uint256 cntBalanceAfter = address(animeRole).balance;
        console.log("test_mint_happycase_simple, caller balance after: ", address(caller).balance);

        assertEq(cntBalanceAfter - cntBalanceBefore, mintNum * mintCost);
        assertEq(animeRole.totalMinted(mintId), mintNum);
        assertEq(animeRole.userTotalMinted(caller, mintId), mintNum);
        assertEq(animeRole.balanceOf(caller, mintId), mintNum);
    }

    function test_mint_happycase_two_callers(uint256 num1, uint256 num2) public {
        uint32 mintId = 1;
        num1 = bound(num1, 1, animeRole.maxSupply(mintId) - 1);
        uint32 mintNum = SafeCast.toUint32(num1);

        vm.warp(block.timestamp + 1 days + 1 minutes);

        // caller 1
        uint256 cntBalanceBefore = address(animeRole).balance;
        vm.startPrank(caller);
        animeRole.mintAnimeRoleNft{value: mintNum * mintCost}(mintId, mintNum);
        vm.stopPrank();
        uint256 cntBalanceAfter = address(animeRole).balance;
        assertEq(cntBalanceAfter - cntBalanceBefore, mintNum * mintCost);

        assertEq(animeRole.totalMinted(mintId), mintNum);
        assertEq(animeRole.userTotalMinted(caller, mintId), mintNum);
        assertEq(animeRole.balanceOf(caller, mintId), mintNum);

        // caller 2
        address caller2 = address(0x200);
        vm.deal(caller2, 10000 ether);
        num2 = bound(num2, 1, animeRole.maxSupply(mintId) - num1);

        uint32 mintNum2 = SafeCast.toUint32(num2);

        cntBalanceBefore = address(animeRole).balance;
        vm.startPrank(caller2);
        animeRole.mintAnimeRoleNft{value: mintNum2 * mintCost}(mintId, mintNum2);
        vm.stopPrank();
        cntBalanceAfter = address(animeRole).balance;
        assertEq(cntBalanceAfter - cntBalanceBefore, mintNum2 * mintCost);

        assertEq(animeRole.totalMinted(mintId), mintNum + mintNum2);
        assertEq(animeRole.userTotalMinted(caller2, mintId), mintNum2);
        assertEq(animeRole.balanceOf(caller2, mintId), mintNum2);
    }

    /**
     * @dev this test takes a long time to run
     */
    function test_mint_happycase_many_times(uint256 num) public {
        uint32 testMintId = 1;
        maxSupply = 10000;
        animeRole.setMaxSupply(testMintId, 10000);
        num = bound(num, 1, animeRole.maxSupply(testMintId));
        uint32 _mintNum = SafeCast.toUint32(num);
        uint32 testMintMax = SafeCast.toUint32(maxSupply);

        uint32 mintBatch = testMintMax / _mintNum;

        vm.warp(block.timestamp + 1 days + 1 minutes);
        for (uint32 i = 0; i < mintBatch; i++) {
            uint32 mintId = testMintId;

            // try to mint max num of nft
            uint32 currMintNum = _mintNum;
            if (i == mintBatch - 1) {
                currMintNum = SafeCast.toUint32(maxSupply - animeRole.totalMinted(mintId));
            }

            if (currMintNum == 0) {
                break;
            }

            uint256 totalMintedBefore = animeRole.totalMinted(mintId);
            uint256 balanceBefore = animeRole.balanceOf(caller, mintId);

            uint256 cntBalanceBefore = address(animeRole).balance;
            {
                vm.startPrank(caller);
                animeRole.mintAnimeRoleNft{value: currMintNum * mintCost}(
                    mintId, currMintNum
                );
                vm.stopPrank();
            }
            
            uint256 cntBalanceAfter = address(animeRole).balance;
            assertEq(cntBalanceAfter - cntBalanceBefore, currMintNum * mintCost);

            assertEq(animeRole.totalMinted(mintId), totalMintedBefore + currMintNum);
            assertEq(animeRole.balanceOf(caller, mintId), balanceBefore + currMintNum);
        }
    }

    function test_publish_nft_happycase(uint256 num) public {
        num = bound(num, 1, 1000);
        for (uint32 i = 0; i < num; i++) {
            animeRole.publishNft(sakura_uri, maxSupply, mintCost);
            assertEq(animeRole.nftId(), i + 4);
            assertEq(animeRole.uri(i + 4), sakura_uri);
            assertEq(animeRole.maxSupply(i + 4), maxSupply);
            assertEq(animeRole.mintPrice(i + 4), mintCost);
        }
    }

    function test_setters_happycase() public {
        console.log("test_setters_happycase, caller address: ", msg.sender);
        uint256 newMaxSupply = 20000;
        animeRole.setMaxSupply(1, newMaxSupply);
        assertEq(animeRole.maxSupply(1), newMaxSupply);

        uint256 newStartAt = currentTs + 2 days;
        animeRole.setStartAt(newStartAt);
        assertEq(animeRole.startAt(), newStartAt);

        bool newPaused = true;
        animeRole.setPause(newPaused);
        assertEq(animeRole.paused(), newPaused);

        string memory newUri = "https://newUri.io/";
        animeRole.setURI(newUri, 1);
        assertEq(animeRole.uri(1), "https://newUri.io/");

        address newSigner = address(0x222);
        animeRole.addSigner(newSigner);
        address[] memory signers = animeRole.getSigners();
        assertEq(signers.length, 2);
        assertEq(signers[0], vm.addr(animeRoleSignerPvKey));
        assertEq(signers[1], newSigner);

        animeRole.delSigner(newSigner);
        signers = animeRole.getSigners();
        assertEq(signers.length, 1);
        assertEq(signers[0], vm.addr(animeRoleSignerPvKey));

        address newDefaultRecipient = address(0x333);
        uint96 newFee = 4231;
        animeRole.setDefaultRoyalty(newDefaultRecipient, newFee);

        (address recipient, uint256 fee) = animeRole.royaltyInfo(1, 10000);
        assertEq(recipient, newDefaultRecipient);
        assertEq(fee, newFee);
    }

    function test_mint_failcase_exceeds_and_out_of_max_supply(uint256 num) public {
        num = bound(num, animeRole.maxSupply(1) + 1, animeRole.maxSupply(1) + 10000);
        uint32 mintNum = SafeCast.toUint32(num);
        uint32 mintId = 1;

        vm.warp(block.timestamp + 1 days + 1 minutes);

        vm.startPrank(caller);
        vm.expectRevert("exceed the nft id max supply");
        animeRole.mintAnimeRoleNft{value: mintNum * mintCost}(mintId, mintNum);
        vm.stopPrank();

        assertEq(caller.balance, 10000 ether);
        assertEq(address(animeRole).balance, 0);

        assertEq(animeRole.totalMinted(mintId), 0);
        assertEq(animeRole.balanceOf(caller, mintId), 0);
    }

    function test_mint_failcase_exceeds_user_balance(uint256 num) public {
        num = bound(num, 1000, 10000);
        uint32 mintNum = SafeCast.toUint32(num);
        uint32 mintId = 1;

        vm.warp(block.timestamp + 1 days + 1 minutes);

        vm.startPrank(caller);
        vm.deal(caller, 0.1 ether);
        vm.expectRevert("Incorrect ETH amount");
        animeRole.mintAnimeRoleNft{value: mintCost}(mintId, mintNum);
        vm.stopPrank();
    }

    function test_mint_failcase_exceeds_nft_id(uint256 num) public {
        num = bound(num, 1000, 10000);
        uint32 mintNum = SafeCast.toUint32(num);
        uint32 mintId = 4;

        vm.warp(block.timestamp + 1 days + 1 minutes);

        vm.startPrank(caller);
        vm.expectRevert("nft id not published");
        animeRole.mintAnimeRoleNft{value: num * mintCost}(mintId, mintNum);
        vm.stopPrank();
    }

    function test_setters_failcase_403() public {
        vm.startPrank(address(0x200));
        uint256 newMaxSupply = 20000;
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animeRole.setMaxSupply(1, newMaxSupply);

        uint256 newStartAt = currentTs + 2 days;
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animeRole.setStartAt(newStartAt);

        bool newPaused = true;
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animeRole.setPause(newPaused);

        string memory newUri = "https://newUri.io/";
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animeRole.setURI(newUri, 1);

        address newSigner = address(0x222);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animeRole.addSigner(newSigner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animeRole.delSigner(newSigner);

        address newDefaultRecipient = address(0x333);
        uint96 newFee = 4231;
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animeRole.setDefaultRoyalty(newDefaultRecipient, newFee);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animeRole.resetTokenRoyalty(1);
        vm.stopPrank();
    }

    function test_distribute_happycase(uint256 amount) public {
        amount = bound(amount, 1, 9999 ether);
        uint256 amount2 = 10000 ether - amount;

        vm.deal(address(animeRoleWithDefinedOwner), 10001 ether);

        address target1 = address(0x2763);
        address target2 = address(0x2764);

        console.log("animeRoleWithDefinedOwner balance before: ", address(animeRoleWithDefinedOwner).balance);

        address[] memory targets = new address[](2);
        targets[0] = target1;
        targets[1] = target2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount2;

        vm.startPrank(definedOwner);
        AnimeRole(animeRoleWithDefinedOwner).addFundGuardian(definedOwner);
        AnimeRole(animeRoleWithDefinedOwner).addFundGuardian(target1);
        AnimeRole(animeRoleWithDefinedOwner).addFundGuardian(target2);
        AnimeRole(animeRoleWithDefinedOwner).distribute(targets, amounts);
        vm.stopPrank();

        assertEq(address(animeRoleWithDefinedOwner).balance, 1 ether);
        assertEq(target1.balance, amount);
        assertEq(target2.balance, amount2);
    }

    function test_distribute_403(uint256 amount) public {
        amount = bound(amount, 1, 9999 ether);
        uint256 amount2 = 10000 ether - amount;

        vm.deal(address(animeRoleWithDefinedOwner), 10001 ether);

        address target1 = address(0x2763);
        address target2 = address(0x2764);

        console.log("animeRoleWithDefinedOwner balance before: ", address(animeRoleWithDefinedOwner).balance);

        address[] memory targets = new address[](2);
        targets[0] = target1;
        targets[1] = target2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount2;

        vm.startPrank(definedOwner);
        AnimeRole(animeRoleWithDefinedOwner).addFundGuardian(target1);
        AnimeRole(animeRoleWithDefinedOwner).addFundGuardian(target2);
        vm.expectRevert("onlyFundGuardian");
        AnimeRole(animeRoleWithDefinedOwner).distribute(targets, amounts);
        vm.stopPrank();
    }

    function test_withdraw_happycase(uint256 amount) public {
        amount = bound(amount, 1, 10000 ether);

        vm.deal(address(animeRoleWithDefinedOwner), 10000 ether);

        uint256 definedOwnerBalBefore = definedOwner.balance;

        vm.startPrank(definedOwner);
        AnimeRole(animeRoleWithDefinedOwner).addFundGuardian(definedOwner);
        animeRoleWithDefinedOwner.withdraw(amount);
        vm.stopPrank();

        assertEq(address(animeRoleWithDefinedOwner).balance, 10000 ether - amount);
        assertEq(definedOwner.balance - definedOwnerBalBefore, amount);
    }

    function test_withdraw_failcase_exceeds(uint256 amount) public {
        amount = bound(amount, 10001 ether, 20000 ether);

        vm.deal(address(animeRoleWithDefinedOwner), 10000 ether);

        vm.startPrank(definedOwner);
        AnimeRole(animeRoleWithDefinedOwner).addFundGuardian(definedOwner);
        vm.expectRevert("Insufficient balance");
        animeRoleWithDefinedOwner.withdraw(amount);
        vm.stopPrank();
    }

    function test_withdraw_failcase_403() public {
        vm.startPrank(address(0x300));
        string[] memory uri = new string[](3);
        uri[0] = sasuke_uri;
        uri[1] = naruto_uri;
        uri[2] = sakura_uri;
        address animalRoleProxy = Upgrades.deployTransparentProxy(
            "AnimeRole.sol",
            proxyAdmin,
            abi.encodeCall(AnimeRole.initialize, (uri, currentTs + 1 days))
        );
        AnimeRole animalRoleLocal = AnimeRole(animalRoleProxy);

        vm.deal(address(animalRoleLocal), 10000 ether);
        vm.stopPrank();

        vm.startPrank(address(0x200));
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0x200)));
        animalRoleLocal.withdraw(1000 ether);
        vm.stopPrank();
    }
}
