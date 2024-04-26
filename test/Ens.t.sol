//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ENS} from "src/Ens.sol";

contract EnsTest is Test {
    error IncorrectAmount();
    error OutOfBounds();
    error AlreadyRegistered();
    error NotOwner();

    struct Info {
        address user;
        uint96 timestamp;
        uint128 price;
        uint128 subscriptionEndsAt;
    }

    ENS internal ens;
    address internal user;
    uint88 internal ensPrice = 1e18;

    function setUp() public {
        ens = new ENS(msg.sender, ensPrice, 1000);
        user = address(uint160(uint256(keccak256("user"))));
        vm.deal(user, 1000e18);
    }

    function test_RegisterUser() public {
        registerUser("name", 10);

        address _addr = ens.getAddress("name");
        assertEq(_addr, address(this));
    }

    function test_ExtendDuration() public {
        vm.warp(1641070800);
        registerUser("name", 10);

        uint256 timeToSkip = block.timestamp + (31536000 * 9);
        vm.warp(timeToSkip);

        // extend by 10 more years
        // the price is (pricePerYear * time * basisPoints) / BP_MAX
        // (1e18 * 10 * 1000) / 10000 = 1e18
        // price for new domain is 10e18
        ens.updateDomainDuration{value: 1e18}("name", 10);

        assertEq(ens.getEndTime("name"), (block.timestamp + 10 * 31536000));
    }

    function test_Register_TheSameDomainNameAfterExpiration() public {
        vm.warp(1641070800);
        string memory name = "name";
        registerUser(name, 10);
        console.log(ens.getAddress(name));

        uint256 timeToSkip = block.timestamp + (31536000 * 11);
        vm.warp(timeToSkip);

        vm.prank(user);
        registerUser(name, 10);
        console.log(ens.getAddress(name));
    }

    function test_RegDom_RevetsIf_DomainName_IsTaken() public {
        vm.warp(1641070800);
        string memory name = "name";
        registerUser(name, 10);

        vm.expectRevert(AlreadyRegistered.selector);
        vm.prank(user);
        registerUser(name, 10);
    }

    function testFuzz_ExtendDuration_RevertsIf_IncorrectAmount(
        uint96 amount
    ) public {
        vm.warp(1641070800);
        registerUser("name", 10);

        uint256 timeToSkip = block.timestamp + (31536000 * 9);
        vm.warp(timeToSkip);

        // extend by 10 more years
        // the price is (pricePerYear * time * basisPoints) / BP_MAX
        // price to extend: (1e18 * 10 * 1000) / 10000 = 1e18
        // price for new domain would be 10e18
        vm.assume(amount < 1e18);
        vm.expectRevert(IncorrectAmount.selector);
        ens.updateDomainDuration{value: amount}("name", 10);
    }

    function testFuzz_ContractBalanceAfterRegistration(uint96 time) public {
        vm.assume(time < 10 && time > 0);
        registerUser("name", time);

        assertEq(ens.contractBalance(), ensPrice * time);
    }

    function testFuzz_RegDom_RevertsIf_OOB(uint96 amount) public {
        vm.assume(amount > 10);
        vm.expectRevert(OutOfBounds.selector);
        ens.registerDomain("name", amount);
        vm.expectRevert(OutOfBounds.selector);
        ens.registerDomain("name", 0);
    }

    function testFuzz_RegDom_RevertsIf_IncorrectPrice(
        uint96 price,
        uint96 time
    ) public {
        vm.assume(time > 0 && time < 10);
        vm.assume(price < 1e18 * time);
        vm.expectRevert(IncorrectAmount.selector);
        ens.registerDomain{value: price}("name", time);
    }

    function testFuzz_Register_TheSameDomainNameAfterExpiration(
        uint96 amount,
        uint96 time
    ) public {
        vm.assume(time > 0 && time < 10);
        vm.warp(1641070800);
        string memory name = "name";
        registerUser(name, time);
        console.log(ens.getAddress(name));

        vm.assume(amount > 10 && amount < 10000000);
        uint256 timeToSkip = block.timestamp + (31536000 * amount);
        vm.warp(timeToSkip);

        vm.prank(user);
        registerUser(name, time);
        console.log(ens.getAddress(name));
    }

    function registerUser(string memory name, uint256 time) public {
        ens.registerDomain{value: 1e18 * time}(name, time);
    }
}
