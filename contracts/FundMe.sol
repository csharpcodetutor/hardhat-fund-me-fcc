//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";
import "hardhat/console.sol";

error FundMe__NotOwner();
error FundMe__NotEnoughEth();
error FundMe__WithdrawFailed();
error FundMe__CheaperWithdrawFailed();

/** @title A contract for crowd funding
 *  @author Joseph Johnson
 *  @notice This contract is to demo a sample funding contract
 *  @dev This implements price feeds as our library *
 */
contract FundMe {
    using PriceConverter for uint256;

    mapping(address => uint256) private s_addressToAmountFunded;

    address[] private s_funders;
    address private immutable i_owner;
    uint256 public constant MINIMUM_USD = 50 * 10**18;

    AggregatorV3Interface private s_priceFeed;

    modifier onlyOwner() {
        //require(msg.sender == i_owner, "Sender is not owner!");
        if (msg.sender != i_owner) {
            console.log(
                "%s does not own this contract! Transaction has been reverted",
                msg.sender
            );
            revert FundMe__NotOwner();
        }
        _;
    }

    constructor(address priceFeedAddress) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    function fund() public payable {
        if (msg.value.getConversionRate(s_priceFeed) < MINIMUM_USD) {
            console.log("Not enough ETH sent");
            revert FundMe__NotEnoughEth();
        }
        console.log(
            "%s is funding the contract %s ETH",
            msg.sender,
            msg.value / 1e18
        );
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }

    function withdraw() public onlyOwner {
        for (uint256 i = 0; i < s_funders.length; i++) {
            s_addressToAmountFunded[s_funders[i]] = 0;
        }
        console.log(
            "%s is trying to withdrawing ETH from the contract",
            i_owner
        );
        s_funders = new address[](0);

        uint256 bal = address(this).balance;

        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!callSuccess) {
            console.log("Call to withdraw failed!");
            revert FundMe__WithdrawFailed();
        }

        console.log(
            "Owner: %s has withdrawing %s ETH from the contract",
            i_owner,
            bal / 1e18
        );
    }

    function cheaperWithdraw() public payable onlyOwner {
        address[] memory funders = s_funders;
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);

        uint256 bal = address(this).balance;

        (bool callSuccess, ) = i_owner.call{value: address(this).balance}("");

        if (!callSuccess) {
            console.log("Call to withdraw (cheaper) failed!");
            revert FundMe__CheaperWithdrawFailed();
        }

        console.log(
            "Owner: %s has withdrawing %s ETH from the contract",
            i_owner,
            bal / 1e18
        );
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(address funder)
        public
        view
        returns (uint256)
    {
        return s_addressToAmountFunded[funder];
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}
