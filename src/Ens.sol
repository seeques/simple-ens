//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ENS {
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

    mapping(string => Info) public domainToInfo;
    uint256 public contractBalance;
    uint96 public pricePerYear;
    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _owner, uint96 _price) {
        owner = _owner;
        pricePerYear = _price;
    }

    function registerDomain(string memory name, uint256 time) external payable {
        if (time > 10 || time < 1) revert OutOfBounds();
        if (msg.value < pricePerYear * time) revert IncorrectAmount();
        contractBalance = contractBalance + msg.value;

        Info storage i = domainToInfo[name];
        uint128 endTime = i.subscriptionEndsAt;

        // if endTime is more than the current timestamp, it means that domain name is owned by someone
        if (block.timestamp <= endTime) revert AlreadyRegistered();

        // if a domain name is expired, rewrite it
        if (i.user != address(0) && block.timestamp > endTime) {
            delete domainToInfo[name];
            i.user = msg.sender;
            i.timestamp = uint96(block.timestamp);
            i.price = uint128(msg.value);
            i.subscriptionEndsAt = uint128(block.timestamp + (time * 31536000));
            return;
        }

        // if it wasn't rewritten previously, this is new domain
        i.user = msg.sender;
        i.timestamp = uint96(block.timestamp);
        i.price = uint128(msg.value);
        i.subscriptionEndsAt = uint128(block.timestamp + (time * 31536000));
    }

    function setPrice(uint96 price) external onlyOwner {
        pricePerYear = price;
    }

    function withdraw(uint256 amount) external onlyOwner {
        contractBalance = contractBalance - amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function getAddress(
        string memory name
    ) external view returns (address user) {
        return user = domainToInfo[name].user;
    }

    function getEndTime(
        string memory name
    ) external view returns (uint128 time) {
        return time = domainToInfo[name].subscriptionEndsAt;
    }
}
