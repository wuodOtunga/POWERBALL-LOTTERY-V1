//SPDX-License-Identifier:MIT

pragma solidity 0.8.30;

contract Powerball {

    //EVENTS
    event TicketPurchased(address indexed player, uint256 indexed ticketNumber, uint256 ticketPrice);
    event PlayersRefunded(address indexed player, uint256 indexed ticketNumber, uint256 ticketPrice);
    event StateChanged(PowerballState newState, PowerballState oldState, uint256 timestamp);
    event WinnerFound(address winner, uint256 winnerPrizeAmount);
    event PrizePoolTransfered(address winner, uint256 winnerPrizeAmount);
    event RoundReset(address owner, uint256 timestamp);

        //STATE VARIABLES.
    uint256 public constant TICKET_PRICE = 0.2 ether;
    uint256 public constant MAX_USERS = 1000;
    uint256 public constant MIN_USERS = 300;

    uint256 public s_roundTime;
    uint256 public s_ticketNumber;
    uint256 public s_drawTime;
    uint256 public s_winnerPrizeAmount;
    address public s_winner;
    uint256 public s_platformFees;
    bool public refundsAvailable = false;
    
    address public immutable i_owner;
    
    address[] public s_players;
    uint256 public players;

    mapping(address player => uint256 ticketNumber) public s_playerAddressToTicketNumber;

        enum PowerballState {
        Opened,
        Closed,
        Cancelled,
        Drawing,
        Completed
    }

    PowerballState state;

    //CUSTOM ERRORSv2-core
    error Powerball__NotOwner();
    error Powerball__InsufficientFunds(uint256 sent, uint256 required);
    error Powerball__RoundClosed();
    error Powerball__TransferFailed();
    error Powerball__InvalidStateAction();
    error Powerball__MaxUsersReached();
    error Powerball__OneTicketPerUser();
    error Powerball__MinUsersNotAttained(uint256 players, uint256 MIN_USERS);
    error Powerball__AddressNotFound();
    error Powerball__RefundsUnavailable();

    
