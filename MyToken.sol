//SPDX-License-Identifier:MIT

pragma solidity 0.8.29;

contract MyToken {

    //CUSTOM ERRORS
    error MyToken__TransferFailed();
    error MyToken__InsufficientBalance();
    error MyToken__NotOwner();
    error MyToken__NotPaused();
    error MyToken__Paused();
    error MyToken__InvalidAddress();
    error MyToken__InsufficientAllowance();
    error MyToken__InvalidInputParameter();

    //STANDARD ERC20 EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    //ADDITIONAL EVENTS.
    event Mint(address to, uint256 amount);
    event Burn(address from, uint256 amount);
    event Paused(address owner);
    event Unpaused(address owner);
    event OwnershipTransfered(address previousOwner, address newOwner);

    //STATE VARIABLES
    //TOKEN METADATA
    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint8 public decimals;

    address private owner;
    bool private paused;

    mapping(address owner => uint256 amount) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowances;

    //MODIFIERS
    modifier onlyOwner {
        if (msg.sender != owner) revert MyToken__NotOwner();
        _;
    }

    modifier whenPaused {
        if (! paused) revert MyToken__NotPaused();
        _;
    }

    modifier whenNotPaused {
        if (paused) revert MyToken__Paused();
        _;
    }

    //CONSTRUCTOR
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        decimals = _decimals;
        owner = msg.sender;
        paused = false;

        if (_initialSupply > 0) {
            _mint(msg.sender, _initialSupply);
        }

        emit OwnershipTransfered(address(0), msg.sender);
    }

    //FUNCTIONS
    function transfer(address to, uint256 amount) public whenNotPaused returns (bool) {
        if (to == address(0)) revert MyToken__InvalidAddress();
        if (amount <= 0) revert MyToken__InsufficientAllowance();
        _transfer(msg.sender, to, amount);

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public whenNotPaused returns (bool) {
        uint256 currentAllowance = allowances[from][msg.sender];
        if (currentAllowance < amount) revert MyToken__InsufficientBalance();
        uint256 ownerBalance = balanceOf[from];
        if (ownerBalance < amount) revert MyToken__InsufficientBalance();
        allowances[from][msg.sender] = currentAllowance - amount; 

        _transfer(from, to, amount);
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address _owner, address spender) public view returns (uint256) {
        return allowances[_owner][spender];
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);

    emit Mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    
    emit Burn(from, amount);
    }

    function increaseAllowance(address spender, uint256 addValue) public returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][spender];
        currentAllowance += addValue;
        _approve(msg.sender, spender, currentAllowance);

        emit Approval(msg.sender, spender, currentAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subValue) public returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][spender];
        if (currentAllowance < subValue) revert MyToken__InsufficientAllowance();
        currentAllowance -= subValue;
        _approve(msg.sender, spender, currentAllowance);

        emit Approval(msg.sender, spender, currentAllowance);
        return true;
    }

    function burnFrom(address from, uint256 amount) public {
        if (amount == 0) revert MyToken__InvalidInputParameter();
        if (from == address(0)) revert MyToken__InvalidAddress();
        uint256 userBalance = balanceOf[from];
        if (userBalance < amount) revert MyToken__InsufficientBalance();
        uint256 currentAllowance = allowances[from][msg.sender];
        if (currentAllowance < amount) revert MyToken__InsufficientAllowance();

        allowances[from][msg.sender] -= amount;
        totalSupply -= amount;

        emit Burn(from, amount);
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;

        emit Paused(owner);
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;

        emit Unpaused(owner);
    }

    function transferOwnership(address _owner, address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert MyToken__InvalidAddress();
        _owner = newOwner;

        emit OwnershipTransfered(msg.sender, newOwner);
    }

    //INTERNAL HELPER FUNCTIONS
    function _approve(address _owner, address spender, uint256 amount) internal {
        if (_owner == address(0)) revert MyToken__InvalidAddress();
        if (spender == address(0)) revert MyToken__InvalidAddress();

        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        uint256 userBalance = balanceOf[from];
        if (userBalance < amount) revert MyToken__InsufficientBalance();
        if (from == address(0)) revert MyToken__InvalidAddress();
        if (to == address(0)) revert MyToken__InvalidAddress();

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert MyToken__InvalidAddress();
        if (amount < 0) revert MyToken__InvalidInputParameter();

        balanceOf[to] += amount;
        totalSupply += amount;

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert MyToken__InvalidAddress();
        if (amount < 0) revert MyToken__InvalidInputParameter();

        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
        emit Burn(from, amount);
    }
}