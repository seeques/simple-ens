//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract ENS {
    error IncorrectAmount();
    error OutOfBounds();
    error AlreadyRegistered();
    error IncorrectDomainName();
    error NotOwner();

    struct Info {
        address user;
        uint96 timestamp;
        uint128 price;
        uint128 subscriptionEndsAt;
    }

    uint256 constant BP_MAX = 10000; //10000 is 100%
    uint256 constant ONE_YEAR = 31536000;

    mapping(string => Info) public domainToInfo;
    uint128 public contractBalance;
    uint128 public pricePerYear;
    uint96 private basisPoints;
    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _owner, uint128 _price, uint8 _bP) {
        require(_bP <= BP_MAX);
        owner = _owner;
        pricePerYear = _price;
        basisPoints = _bP;
    }

    function registerDomain(string memory name, uint256 time) external payable {
        if (time > 10 || time < 1) revert OutOfBounds();
        if (msg.value < pricePerYear * time) revert IncorrectAmount();
        contractBalance = uint128(contractBalance + msg.value);

        Info storage i = domainToInfo[name];
        uint128 endTime = i.subscriptionEndsAt;

        // if endTime is more than the current timestamp, it means that domain name is owned by someone
        if (block.timestamp <= endTime) revert AlreadyRegistered();

        // if a domain name is expired, rewrite it
        if (i.user != address(0) && block.timestamp > endTime) {
            // delete domainToInfo[name];
            i.user = msg.sender;
            i.timestamp = uint96(block.timestamp);
            i.price = uint128(msg.value);
            i.subscriptionEndsAt = uint128(block.timestamp + (time * ONE_YEAR));
            return;
        }

        // if it wasn't rewritten previously, it is new
        i.user = msg.sender;
        i.timestamp = uint96(block.timestamp);
        i.price = uint128(msg.value);
        i.subscriptionEndsAt = uint128(block.timestamp + (time * ONE_YEAR));
    }

    function extendDomainDuration(
        string memory name,
        uint256 time
    ) external payable {
        if (time > 10 || time < 1) revert OutOfBounds();
        Info storage i = domainToInfo[name];
        uint256 endTime = i.subscriptionEndsAt;
        if (i.user != msg.sender || block.timestamp > endTime)
            revert IncorrectDomainName();

        uint256 newPrice = (pricePerYear * time * basisPoints) / BP_MAX;
        if (msg.value < newPrice) revert IncorrectAmount();

        // new end time should start from the previous end time
        uint128 newEndTime = uint128(endTime + (time * ONE_YEAR));

        // write to storage
        i.subscriptionEndsAt = newEndTime;
        i.price = uint128(msg.value);
    }

    function setPrice(uint88 price) external onlyOwner {
        pricePerYear = price;
    }

    function withdraw(uint256 amount) external onlyOwner {
        contractBalance = uint128(contractBalance - amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function getAddress(
        string memory name
    ) external view returns (address user) {
        user = domainToInfo[name].user;
    }

    function getEndTime(
        string memory name
    ) external view returns (uint128 time) {
        time = domainToInfo[name].subscriptionEndsAt;
    }
}
