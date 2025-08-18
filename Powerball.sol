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
    

    //MODIFIERS
    modifier onlyOwner {
        if (msg.sender != i_owner) revert Powerball__NotOwner();
        _;
    }

    modifier inState(PowerballState _state) {
        if (state != _state) revert Powerball__InvalidStateAction();
        _;
    }

    modifier transitionNext() {
        _;
        if (block.timestamp >= s_roundTime + 24 hours) {
            nextState();
        }
    }

    //CONSTRUCTOR
    constructor() {
        i_owner = msg.sender;
        s_roundTime = block.timestamp;
        s_drawTime = block.timestamp;
        state = PowerballState.Opened;
    }

    //FUNCTIONS
    function buyTicket() public payable inState(PowerballState.Opened) transitionNext {
        
        if (s_players.length >= MAX_USERS) revert Powerball__MaxUsersReached();

        if (block.timestamp >= s_roundTime + 24 hours) revert Powerball__RoundClosed();

        if (msg.value < TICKET_PRICE) revert Powerball__InsufficientFunds(msg.value, TICKET_PRICE);

        if (s_playerAddressToTicketNumber[msg.sender] != 0) revert Powerball__OneTicketPerUser();

        s_ticketNumber++;
        s_players.push(msg.sender);

        s_playerAddressToTicketNumber[msg.sender] = s_ticketNumber;
        emit TicketPurchased(msg.sender, s_ticketNumber, TICKET_PRICE);
    }

    function refundPlayers() public inState(PowerballState.Closed) onlyOwner {
        //INPUT VALIDATION
        if (s_players.length > MIN_USERS) {
            revert Powerball__InvalidStateAction();
        }
        if (block.timestamp < s_roundTime + 24 hours) {
            revert Powerball__InvalidStateAction();
        }

        //SET REFUNDS AVAILABLE
        refundsAvailable = true;
        //STATE TRANSITION
        state = PowerballState.Cancelled;

        //EMIT
        emit StateChanged(PowerballState.Closed, PowerballState.Cancelled, block.timestamp);
    }

    function startDraw() public inState(PowerballState.Closed) {
        //INPUT VALIDATION.
        if (s_players.length < MIN_USERS) {
            revert Powerball__MinUsersNotAttained(players, MIN_USERS);
        }
        //STATE TRANSITION
        state = PowerballState.Drawing;
        //CALCULATE PRIZE POOL
        uint256 totalPrizePool = s_players.length * TICKET_PRICE;
        s_platformFees = totalPrizePool/10;
        s_winnerPrizeAmount = totalPrizePool - s_platformFees;

        //START RANDOMNESS PROCESS
        bytes32 hashDigit = keccak256(abi.encodePacked(block.timestamp, msg.sender, players, blockhash(block.number - 1)));
        uint256 randomIndex = uint256(hashDigit);
        uint256 winnersIndex = randomIndex % players;

        //PICK THE WINNER
        s_winner = s_players[winnersIndex]; 

        //EMIT EVENT
        emit WinnerFound(s_winner, s_winnerPrizeAmount);

    }

    function closeDraw() public inState(PowerballState.Drawing) {
        //CHECK TO SEE IF IT IS CALLED BEFORE 3 DAYS.
        if (block.timestamp < s_drawTime + 3 days) {
            revert Powerball__InvalidStateAction();
        }
        //TRANSFER PRIZE POOL
        (bool success,) = payable(s_winner).call{value: s_winnerPrizeAmount}("");
        if (! success) revert Powerball__TransferFailed();

        //STATE TRANSITION
        state = PowerballState.Completed;

        //EMITS
        emit StateChanged(PowerballState.Drawing, PowerballState.Completed, block.timestamp);
        emit PrizePoolTransfered(s_winner, s_winnerPrizeAmount);
    }

    function resetRound() public inState(PowerballState.Completed) onlyOwner {
        //RESET STATE VARIABLES
        s_roundTime = 0;
        s_ticketNumber = 0;
        s_winnerPrizeAmount = 0;
        s_winner = address(0);

        //RESET MAPPING
        for (uint256 i = 0; i < s_players.length; i++) {
            address player = s_players[i];
            delete s_playerAddressToTicketNumber[player]; 
        }
        //RESET S_PLAYERS ARRAY
        delete s_players;

        //TRANSFER PLATFORM FEES TO DEV WALLET ADDRESS.
        (bool success,) = payable(msg.sender).call{value: s_platformFees}("");
        if (! success) {
            revert Powerball__TransferFailed();
        }

        //STATE TRANSITION
        state = PowerballState.Opened;

        //EMIT
        emit RoundReset(i_owner, block.timestamp);
    }

    function claimRefunds() public inState(PowerballState.Cancelled) {
        //VALIDATION CHECKS
        if (s_playerAddressToTicketNumber[msg.sender] == 0) {
            revert Powerball__AddressNotFound();
        }
        if (!refundsAvailable) {
            revert Powerball__RefundsUnavailable();
        }

        //TRANSFER FUNDS TO USER.
        (bool success,) = payable(msg.sender).call{value: TICKET_PRICE}("");
        if (! success) {
            revert Powerball__TransferFailed();
        }
        //DELETE THE MAPPING TO AVOID DOUBLE SPENDING.
        s_playerAddressToTicketNumber[msg.sender] = 0;

        //EMIT
        emit PlayersRefunded(msg.sender, s_ticketNumber, TICKET_PRICE);
    }

    function nextState() internal {
        state = PowerballState(uint(state) + 1);
    }

    fallback() external payable {
        buyTicket();
    }

    receive() external payable {
        buyTicket();
    }
}