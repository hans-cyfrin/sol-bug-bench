// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy token
        token = new GovernanceToken();

        // Give some tokens to user1 for testing
        token.transfer(user1, 1000 * 10 ** 18);
    }

    function testInitialSupply() public {
        assertEq(token.totalSupply(), 1000000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 999000 * 10 ** 18);
        assertEq(token.balanceOf(user1), 1000 * 10 ** 18);
    }

    function testMinting() public {
        uint256 initialSupply = token.totalSupply();
        uint256 mintAmount = 500 * 10 ** 18;

        token.mint(user2, mintAmount);

        assertEq(token.totalSupply(), initialSupply + mintAmount);
        assertEq(token.balanceOf(user2), mintAmount);
    }

    function testBlacklisting() public {
        // Initially not blacklisted
        assertFalse(token.blacklisted(user1));

        // Blacklist user1
        token.updateUserStatus(user1, true);
        assertTrue(token.blacklisted(user1));

        // Unblacklist user1
        token.updateUserStatus(user1, false);
        assertFalse(token.blacklisted(user1));
    }

    function testTransferWithBlacklist() public {
        // Test transfer from non-blacklisted user
        vm.prank(user1);
        token.transfer(user2, 100 * 10 ** 18);
        assertEq(token.balanceOf(user2), 100 * 10 ** 18);

        // Blacklist user1
        token.updateUserStatus(user1, true);

        // Test transfer from blacklisted user should fail
        vm.prank(user1);
        vm.expectRevert("Sender is blacklisted");
        token.transfer(user2, 100 * 10 ** 18);

        // Test transfer to blacklisted user should fail
        token.updateUserStatus(user1, false);
        token.updateUserStatus(user2, true);

        vm.prank(user1);
        vm.expectRevert("Recipient is blacklisted");
        token.transfer(user2, 100 * 10 ** 18);
    }

    function testTransferToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0)));
        token.transfer(address(0), 100 * 10 ** 18);
    }

    function testApproveToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidSpender(address)", address(0)));
        token.approve(address(0), 100 * 10 ** 18);
    }

    function testTransferFromZeroAddress() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidSender(address)", address(0)));
        token.transfer(address(1), 100 * 10 ** 18);
    }

    function testTransferFromToZeroAddress() public {
        vm.prank(user1);
        token.approve(user2, 1000 * 10 ** 18);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0)));
        token.transferFrom(user1, address(0), 100 * 10 ** 18);
    }

    function testTransferInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)", user1, 1000 * 10 ** 18, 2000 * 10 ** 18
            )
        );
        token.transfer(user2, 2000 * 10 ** 18);
    }

    function testTransferFromInsufficientBalance() public {
        vm.prank(user1);
        token.approve(user2, 2000 * 10 ** 18);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)", user1, 1000 * 10 ** 18, 2000 * 10 ** 18
            )
        );
        token.transferFrom(user1, address(0x3), 2000 * 10 ** 18);
    }

    function testTransferFromInsufficientAllowance() public {
        vm.prank(user1);
        token.approve(user2, 50 * 10 ** 18);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)", user2, 50 * 10 ** 18, 100 * 10 ** 18
            )
        );
        token.transferFrom(user1, address(0x3), 100 * 10 ** 18);
    }

    function testTransferFromWithBlacklist() public {
        // Approve user2 to spend user1's tokens
        vm.prank(user1);
        token.approve(user2, 1000 * 10 ** 18);

        // Test transferFrom with non-blacklisted users
        vm.prank(user2);
        token.transferFrom(user1, address(0x3), 100 * 10 ** 18);
        assertEq(token.balanceOf(address(0x3)), 100 * 10 ** 18);

        // Blacklist sender
        token.updateUserStatus(user1, true);

        // Test transferFrom with blacklisted sender should fail
        vm.prank(user2);
        vm.expectRevert("Sender is blacklisted");
        token.transferFrom(user1, address(0x3), 100 * 10 ** 18);

        // Test transferFrom to blacklisted recipient should fail
        token.updateUserStatus(user1, false);
        token.updateUserStatus(address(0x3), true);

        vm.prank(user2);
        vm.expectRevert("Recipient is blacklisted");
        token.transferFrom(user1, address(0x3), 100 * 10 ** 18);
    }
}
