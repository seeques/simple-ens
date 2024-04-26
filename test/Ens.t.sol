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
        ens = new ENS(msg.sender, ensPrice, 100);
        user = address(uint160(uint256(keccak256("user"))));
        vm.deal(user, 1000e18);
    }

    function test_RegisterUser() public {
        registerUser("name", 10);

        address _addr = ens.getAddress("name");
        assertEq(_addr, address(this));
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

    function test_RegDom_RevetIf_DomainName_IsTaken() public {
        vm.warp(1641070800);
        string memory name = "name";
        registerUser(name, 10);

        vm.expectRevert(AlreadyRegistered.selector);
        vm.prank(user);
        registerUser(name, 10);
    }

    function testFuzz_ContractBalanceAfterRegistration(uint96 time) public {
        vm.assume(time < 10 && time > 0);
        registerUser("name", time);

        assertEq(ens.contractBalance(), ensPrice * time);
    }

    function testFuzz_RegDom_RevertIf_OOB(uint96 amount) public {
        vm.assume(amount > 10);
        vm.expectRevert(OutOfBounds.selector);
        ens.registerDomain("name", amount);
        vm.expectRevert(OutOfBounds.selector);
        ens.registerDomain("name", 0);
    }

    function testFuzz_RegDom_RevertIf_IncorrectPrice(
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
