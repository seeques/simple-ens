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
        uint128 totalPaid;
        uint128 subscriptionEndsAt;
    }

    uint256 public constant BP_MAX = 10000; // 10000 is 100%
    uint256 public constant ONE_YEAR = 31536000;

    mapping(string => Info) public domainToInfo;
    uint128 public contractBalance;
    uint128 public pricePerYear;
    uint96 private basisPoints;
    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _owner, uint128 _price, uint96 _bp) {
        if (_bp > BP_MAX) revert OutOfBounds();
        if (_price < BP_MAX) revert OutOfBounds();
        owner = _owner;
        pricePerYear = _price;
        basisPoints = _bp;
    }

    /// @notice Registers domain with specified domain name for specified time, up to 10 years
    /// @dev Function doesn't handle repayments, so it's up to users to calculate the exact value
    /// @param name domain name
    /// @param time number of years for which a user wants to increase duration
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
            // writes to storage
            i.user = msg.sender;
            i.timestamp = uint96(block.timestamp);
            i.totalPaid = uint128(msg.value);
            i.subscriptionEndsAt = uint128(block.timestamp + (time * ONE_YEAR));
            return;
        }

        // if it wasn't rewritten previously, it is new
        // writes to storage
        i.user = msg.sender;
        i.timestamp = uint96(block.timestamp);
        i.totalPaid = uint128(msg.value);
        i.subscriptionEndsAt = uint128(block.timestamp + (time * ONE_YEAR));
    }

    /// @notice Updates the duration of subscription for already existing domain
    /// @dev Duration of the subscription shoud not exceed 10 years from the current block.timestamp
    /// @dev This is why the function doesn't increase the duration, but rather updates it
    /// @param name domain name
    /// @param time number of years for which a user wants to increase duration
    function updateDomainDuration(
        string memory name,
        uint256 time
    ) external payable {
        if (time > 10 || time < 1) revert OutOfBounds();
        Info storage i = domainToInfo[name];
        if (i.user != msg.sender || block.timestamp > i.subscriptionEndsAt)
            revert IncorrectDomainName();

        // pricePerYear is at least BP_MAX so the price won't round to 0
        uint256 newPrice = (pricePerYear * time * basisPoints) / BP_MAX;
        if (msg.value < newPrice) revert IncorrectAmount();

        // new end time starts from current timestamp so that the end time doesn't exceed 10 years
        uint128 newEndTime = uint128(block.timestamp + (time * ONE_YEAR));

        // writes to storage
        i.subscriptionEndsAt = newEndTime;
        i.totalPaid = i.totalPaid + uint128(msg.value);
    }

    /// @notice Sets the price of registering domain for 1 year
    /// @dev Restricted to contract's owner
    /// @param price of registering domain for 1 year, in wei
    function setPrice(uint128 price) external onlyOwner {
        if (price < BP_MAX) revert OutOfBounds();
        pricePerYear = price;
    }

    /// @notice Sets the basis points for updating domain duration calculations
    /// @dev Restricted to contract's owner
    /// @param _bp basis points from 0 to 10000
    function setBP(uint96 _bp) external onlyOwner {
        if (_bp > BP_MAX) revert OutOfBounds();
        basisPoints = _bp;
    }

    /// @notice Withdraws contract's balance
    /// @dev Restricted to contract's owner
    /// @param amount to withdraw
    function withdraw(uint256 amount) external onlyOwner {
        contractBalance = uint128(contractBalance - amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /// @notice Returns the address of a user for the specified domain name
    /// @param name domain name
    /// @return holder of the domain
    function getAddress(
        string memory name
    ) external view returns (address holder) {
        holder = domainToInfo[name].user;
    }

    /// @notice Returns the time at which subscription ends for the specified domain name
    /// @param name domain name
    /// @return time at which subscription ends
    function getEndTime(
        string memory name
    ) external view returns (uint128 time) {
        time = domainToInfo[name].subscriptionEndsAt;
    }
}
