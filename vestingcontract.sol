// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

// Import OpenZeppelin Libraries

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Token is ERC20, ERC20Burnable {
    constructor() ERC20("RastaCoin", "RCOIN") {}
}


/**
 * Staking vesting contract. Tokens released over 10 years.
 * 
 */
contract StakingVesting {
    using SafeMath for uint256;
    // ERC20 basic token contract being held
    address public immutable tokenAddress;

    uint256 public totalTokensRequired;
    
    // beneficiary of tokens after they are released
    mapping(address => uint256) public tokenAmounts;

    // beneficiary of tokens after they are released
    mapping(address => uint256) public totalPercentageWithdrawn;

    // struct to store the vesting release timestamps (in unix format) and the respective release percentages
    struct Vest {
        uint256 releaseTime;
        uint256 releasePercentage;
    }

    // struct instance to store the vesting variables
    Vest[10] public vesting_array;

    /**
     * @dev Deploys a timelock instance that is able to hold the token specified, and will only release it to
     * beneficiary_ when {release} is invoked after releaseTime_. The release time is specified as a Unix timestamp
     * (in seconds).
     */
    constructor(
        address _token,
        address[] memory _beneficiaries,
        uint256[] memory _tokenAmounts,
        uint256[] memory _releaseTimes,
        uint256[] memory _releasePercentages
    ) {
        require(_releaseTimes[0] > block.timestamp, "TokenTimelock: release time is before current time"); // check if the first vesting release time is greater than timestamp for current block 
        require(_beneficiaries.length == _tokenAmounts.length); // check if each beneficiary has a corresponding tokenAmount
        require(_releaseTimes.length == _releasePercentages.length); // check if each releaseTime has a corresponding release percentage
        require(_token != address(0)); // check if the token address is a valid contract address

        tokenAddress = _token; // record the contract address for the tokens being vested

        uint8 maxLen = _tokenAmounts.length > _releaseTimes.length ? uint8(_tokenAmounts.length) : uint8(_releaseTimes.length); // variable to avoid two different loops
        for (uint8 i = 0; i < maxLen; i++) {

            if(i < _tokenAmounts.length) { // check if the complete token Beneficiary arrays have been completely recorded
                require(_tokenAmounts[i] > 0 && _beneficiaries[i] != address(0)); // check if all beneficiaries are valid addresses and token amounts are valid
                tokenAmounts[_beneficiaries[i]] = _tokenAmounts[i]; // record total tokenAmounts for each beneficiary
                totalTokensRequired = totalTokensRequired.add(_tokenAmounts[i]); // record Total Tokens Required as a sum of token amounts for all beneficiaries
            }


            if(i < _releaseTimes.length) { // check if the vesting arrays have been completely recorded
                        require(_releasePercentages[i] > 0); // check if the vesting release percentage is a valid number
                        if (i != 0) {
                            require(_releaseTimes[i] > _releaseTimes[i-1]); // check if all vesting release times are in ascending order, i.e. year 1, year 2, etc.
                        }
                        vesting_array[i].releaseTime = _releaseTimes[i]; // record the vesting release times
                        vesting_array[i].releasePercentage = _releasePercentages[i]; // record the vesting release percentages
                    }
                }
            }
    
    function fundingComplete() public view returns (bool) { // function to check if the vesting contract has the total tokens required for withdrawal later. Contract is invalid if this is not true (only until before the first vesting release time) 
        return Token(tokenAddress).balanceOf(address(this)) == totalTokensRequired;
    }

    function currentVestingRelease() public view returns (uint256 vestingPercentage) { //function to check the current vesting release percentage. Consecutive vesting percentages keep adding up as each vesting period elapses
        for (uint8 i = 0; i < vesting_array.length; i++) {
            if (block.timestamp > vesting_array[i].releaseTime) {
                vestingPercentage = vestingPercentage.add(vesting_array[i].releasePercentage); // at year 2, user should be able to retrieve vested tokens for year 1 + year 2
            }
        }
        return vestingPercentage;
    }

    /**
     * @dev Transfers tokens held by the timelock to the beneficiary. Will only succeed if invoked after the release
     * time.
     */
    function release() public virtual {
        uint256 releasePercentage = currentVestingRelease().sub(totalPercentageWithdrawn[msg.sender]); // check how much the beneficiary has already withdrawn, and only allow retrival of remaining amount
        require(releasePercentage > 0, "TokenTimelock: current time is before release time"); // release percerntage is 0 when the vesting period hasnt started yet.
        require(totalPercentageWithdrawn[msg.sender] < 100, "TokenTimelock: no tokens to release"); // check if the user has any tokens to withdraw

        uint256 amount = tokenAmounts[msg.sender].mul(releasePercentage).div(100); // calculate the token amount that the user can withdraw
        require(amount > 0, "TokenTimelock: no tokens to release"); // check if the user has any tokens to withdraw

        totalPercentageWithdrawn[msg.sender] = totalPercentageWithdrawn[msg.sender].add(releasePercentage); // record total vesting percentage that the beneficiary has already withdrawn
        Token(tokenAddress).transfer(msg.sender, amount); // Transfer the  vested token amount as per current release horizon to the beneficiary
    }
}
