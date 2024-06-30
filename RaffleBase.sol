// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RaffleBase is Ownable {
    IERC20 public usdc;
    address public constant controller = 0x34045c937742C8AD6222A10eb21c7CfFF8Bf870E;

    uint256 public ticketPrice = 9.99 * 10 ** 6; // 9.99 USDC in 6 decimal places
    uint256 public retainer = 100; // 1% in basis points (100 basis points = 1%)
    address[] public participants;
    mapping(address => uint256) public tickets;
    bool public isLotteryActive;
    address[3] public winners;
    uint256 public totalPot;

    event LotteryStarted();
    event LotteryDrawn(address[3] indexed winners, uint256[3] amounts);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    modifier onlyController() {
        require(msg.sender == controller, "Not authorized");
        _;
    }

    constructor(address _usdcAddress, address initialOwner) Ownable(initialOwner) {
        usdc = IERC20(_usdcAddress);
    }

    function DEPOSIT(uint256 numberOfTickets) external {
        require(isLotteryActive, "Raffle not active");
        require(numberOfTickets > 0, "Must buy at least one ticket");
        uint256 amount = numberOfTickets * ticketPrice;
        require(usdc.balanceOf(msg.sender) >= amount, "Insufficient USDC balance");
        require(usdc.allowance(msg.sender, address(this)) >= amount, "Allowance not set");

        usdc.transferFrom(msg.sender, address(this), amount);

        for (uint256 i = 0; i < numberOfTickets; i++) {
            participants.push(msg.sender);
        }

        tickets[msg.sender] += numberOfTickets;
        totalPot += amount;

        emit Deposit(msg.sender, amount);
    }

    function NEW() external onlyController {
        require(!isLotteryActive, "Raffle already active");

        isLotteryActive = true;
        delete participants;
        totalPot = 0;

        emit LotteryStarted();
    }

    function DRAW() external onlyController {
        require(isLotteryActive, "Raffle not active");
        require(participants.length >= 3, "Not enough participants");

        uint256 totalPrize = (totalPot * (10000 - retainer)) / 10000;
        uint256[3] memory prizeAmounts = [
            (totalPrize * 7770) / 10000, // 77.7%
            (totalPrize * 1330) / 10000, // 13.3%
            (totalPrize * 800) / 10000   // 8%
        ];

        for (uint256 i = 0; i < 3; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, participants))) % participants.length;
            winners[i] = participants[randomIndex];
            usdc.transfer(winners[i], prizeAmounts[i]);
            participants[randomIndex] = participants[participants.length - 1];
            participants.pop();
        }

        isLotteryActive = false;

        emit LotteryDrawn(winners, prizeAmounts);
    }

    function checkIfWinner() external view returns (bool) {
        for (uint256 i = 0; i < 3; i++) {
            if (msg.sender == winners[i]) {
                return true;
            }
        }
        return false;
    }

    function WITHDRAW() external onlyController {
        uint256 contractBalance = usdc.balanceOf(address(this));
        uint256 amountToWithdraw = contractBalance - (totalPot * retainer / 10000);

        usdc.transfer(controller, amountToWithdraw);

        emit Withdrawal(controller, amountToWithdraw);
    }

    function getOdds(address user) external view returns (string memory) {
        uint256 userTickets = tickets[user];
        if (participants.length == 0) {
            return "No tickets sold.";
        }

        uint256 oddsNumerator = userTickets * 10000;
        uint256 oddsDenominator = participants.length;
        uint256 odds = oddsNumerator / oddsDenominator;

        return string(abi.encodePacked("Your odds of winning are 1 in ", uint2str(odds)));
    }

    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
