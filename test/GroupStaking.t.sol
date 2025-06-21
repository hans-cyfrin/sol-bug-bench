// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";

contract GroupStakingTest is Test {
    GovernanceToken public token;
    GroupStaking public staking;
    address public owner;
    address public member1;
    address public member2;
    address public member3;

    function setUp() public {
        owner = address(this);
        member1 = address(0x1);
        member2 = address(0x2);
        member3 = address(0x3);

        // Deploy token and staking contracts
        token = new GovernanceToken();
        staking = new GroupStaking(address(token));

        // Give tokens to members for testing
        token.transfer(member1, 1000 * 10 ** 18);
        token.transfer(member2, 1000 * 10 ** 18);
        token.transfer(member3, 1000 * 10 ** 18);
    }

    function testCreateStakingGroup() public {
        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;

        uint256[] memory weights = new uint256[](3);
        weights[0] = 40;
        weights[1] = 35;
        weights[2] = 25;

        uint256 groupId = staking.createStakingGroup(members, weights);
        assertEq(groupId, 1);

        (uint256 id, uint256 totalAmount, address[] memory groupMembers, uint256[] memory groupWeights) =
            staking.getGroupInfo(groupId);

        assertEq(id, groupId);
        assertEq(totalAmount, 0);
        assertEq(groupMembers.length, 3);
        assertEq(groupWeights.length, 3);
        assertEq(groupMembers[0], member1);
        assertEq(groupWeights[0], 40);
    }

    function testStakeToGroup() public {
        // Create group first
        address[] memory members = new address[](2);
        members[0] = member1;
        members[1] = member2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        // Approve and stake tokens
        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(member1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        (, uint256 totalAmount,,) = staking.getGroupInfo(groupId);
        assertEq(totalAmount, stakeAmount);
        assertEq(token.balanceOf(address(staking)), stakeAmount);
    }

    function testWithdrawFromGroup() public {
        // Create group and stake tokens
        address[] memory members = new address[](2);
        members[0] = member1;
        members[1] = member2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(member1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        // Record balances before withdrawal
        uint256 member1BalanceBefore = token.balanceOf(member1);
        uint256 member2BalanceBefore = token.balanceOf(member2);

        // Withdraw half the staked amount
        uint256 withdrawAmount = 50 * 10 ** 18;
        vm.prank(member1);
        staking.withdrawFromGroup(groupId, withdrawAmount);

        // Check balances after withdrawal
        assertEq(token.balanceOf(member1), member1BalanceBefore + (withdrawAmount * 60 / 100));
        assertEq(token.balanceOf(member2), member2BalanceBefore + (withdrawAmount * 40 / 100));

        // Check remaining group balance
        (, uint256 totalAmount,,) = staking.getGroupInfo(groupId);
        assertEq(totalAmount, stakeAmount - withdrawAmount);
    }

    function testGroupMembership() public {
        address[] memory members = new address[](2);
        members[0] = member1;
        members[1] = member2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 50;
        weights[1] = 50;

        uint256 groupId = staking.createStakingGroup(members, weights);

        assertTrue(staking.isMemberOfGroup(groupId, member1));
        assertTrue(staking.isMemberOfGroup(groupId, member2));
        assertFalse(staking.isMemberOfGroup(groupId, member3));
    }

    function testInvalidGroupCreation() public {
        address[] memory members = new address[](2);
        members[0] = member1;
        members[1] = member2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 30; // Sum is 90, should be 100

        vm.expectRevert("Weights must sum to 100");
        staking.createStakingGroup(members, weights);
    }

    function testEmptyMembersList() public {
        address[] memory members = new address[](0);
        uint256[] memory weights = new uint256[](0);

        vm.expectRevert("Empty members list");
        staking.createStakingGroup(members, weights);
    }

    function testMembersWeightsLengthMismatch() public {
        address[] memory members = new address[](2);
        members[0] = member1;
        members[1] = member2;

        uint256[] memory weights = new uint256[](1);
        weights[0] = 100;

        vm.expectRevert("Members and weights length mismatch");
        staking.createStakingGroup(members, weights);
    }

    function testNonExistentGroupStake() public {
        uint256 nonExistentGroupId = 999;
        uint256 stakeAmount = 100 * 10 ** 18;

        vm.startPrank(member1);
        token.approve(address(staking), stakeAmount);
        vm.expectRevert("Group does not exist");
        staking.stakeToGroup(nonExistentGroupId, stakeAmount);
        vm.stopPrank();
    }

    function testInsufficientGroupBalance() public {
        // Create group and stake tokens
        address[] memory members = new address[](2);
        members[0] = member1;
        members[1] = member2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(member1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        // Try to withdraw more than staked
        uint256 withdrawAmount = 200 * 10 ** 18;
        vm.prank(member1);
        vm.expectRevert("Insufficient group balance");
        staking.withdrawFromGroup(groupId, withdrawAmount);
    }

    function testNonExistentGroupInfo() public {
        uint256 nonExistentGroupId = 999;
        vm.expectRevert("Group does not exist");
        staking.getGroupInfo(nonExistentGroupId);
    }

    function testNonMemberWithdraw() public {
        // Create group and stake tokens
        address[] memory members = new address[](2);
        members[0] = member1;
        members[1] = member2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = staking.createStakingGroup(members, weights);

        uint256 stakeAmount = 100 * 10 ** 18;
        vm.startPrank(member1);
        token.approve(address(staking), stakeAmount);
        staking.stakeToGroup(groupId, stakeAmount);
        vm.stopPrank();

        // Try to withdraw as non-member
        vm.prank(member3);
        vm.expectRevert("Not a group member");
        staking.withdrawFromGroup(groupId, 50 * 10 ** 18);
    }
}
