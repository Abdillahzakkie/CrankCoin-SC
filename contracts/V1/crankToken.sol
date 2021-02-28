// SPDX-License-Identifier: MIT 
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract CrankCoin is Ownable, IERC20 {
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping(address => Lock) public locks;
    mapping(address => uint) private _rewardsEarned;

    uint256 private _totalSupply;
    uint256 private _totalSharedRewards;
    uint256 private _totalLockedTokens;

    string private _name;
    string private _symbol;
    
    struct Lock {
        address user;
        uint256 amount;
        uint256 unlockTime;
    }
    
    
    event NewLock(address indexed user, uint256 amount, uint256 unlockTime);
    event NewUnlock(address indexed user, uint256 initialStake, uint256 rewards, uint256 timestamp);
    event RewardShared(uint256 indexed timestamp, uint256 indexed rewards);


    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The defaut value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor() {
        _name = "CrankCoin";
        _symbol = "CKN";
        _totalLockedTokens = 0;
        
        uint256 _amount = 10000 ether;
        _mint(_msgSender(), _amount);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overloaded;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        require(_allowances[sender][_msgSender()] >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        require(_allowances[_msgSender()][spender] >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);

        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        (uint256 _availableBalance, uint256 _tax) =_beforeTokenTransfer(sender, recipient, amount);

        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] -= amount;
        _balances[recipient] += _availableBalance;
        _totalSupply -= _tax;
        
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        require(_balances[account] >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] -= amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function getContractBalance() public view returns(uint256) {
        return _balances[address(this)];
    }
    
    function getTotallockedToken() public view returns(uint256) {
        return _totalLockedTokens;
    }

    function lock(uint _amount) public {
        require(locks[_msgSender()].unlockTime < block.timestamp, "CrankCoin: active lock found. Wait for the current lock time to exceed");
        require(locks[_msgSender()].amount == 0, "CrankCoin: unlock current staked balance");
        require(_amount > 0, "CrankCoin: lock amount must be greater than zero");
        
        _transfer(_msgSender(), address(this), _amount);
        _totalLockedTokens += _amount;
        
        // uint256 _unlockTime = block.timestamp + 30 days;
        uint256 _unlockTime = block.timestamp;

        Lock memory _newLock = Lock(_msgSender(), _amount, _unlockTime);
        locks[_msgSender()] = _newLock;
        emit NewLock(_msgSender(), _amount, _unlockTime);
    }
    
    function unlock() public {
        require(locks[_msgSender()].amount > 0, "CrankCoin: no active lock found");
        require(locks[_msgSender()].unlockTime <= block.timestamp, "CrankCoin: wait till lock time exceeds");
        
        uint256 _lockedBalance = locks[_msgSender()].amount;
        uint256 _contractBalance = getContractBalance();
        uint256 _gains = calculateLockGains(_lockedBalance);
        uint256 _totalBalance = _lockedBalance + _gains;


        locks[_msgSender()].amount = 0;
        _totalSharedRewards += _gains;
        _totalLockedTokens -= _lockedBalance;

        if(_totalBalance > _contractBalance) {
            uint256 _remainingBalance = _totalBalance - _contractBalance;
            _mint(address(this), _remainingBalance);
        }

        _transfer(address(this), _msgSender(), _totalBalance);
        emit NewUnlock(_msgSender(), _lockedBalance, _gains, block.timestamp);
        
        // locks[_msgSender()].amount = 0;
        // _totalLockedTokens -= _lockedBalance;
        
        // if(_contractBalance <= _totalBalance) {
        //     uint256 _remainingBalance = _contractBalance - _totalBalance;
        //     _mint(address(this), _remainingBalance);
        // }
        // transfer(_msgSender(), _totalBalance);
    }
    
    function shareReward(address[] memory _accounts, uint256[] memory _rewards) public onlyOwner {
        uint256 _totalRewards = 0;

        for(uint256 i = 0; i < _accounts.length; i++) {
            address _user = _accounts[i];
            uint256 _reward = _rewards[i];
            if(_user == address(0)) continue;
            
            _totalRewards += _reward;
            _rewardsEarned[_user] += _reward;
        }
        
        _totalSharedRewards += _totalRewards;
        _mint(address(this), _totalRewards);
        emit RewardShared(block.timestamp, _totalRewards);
    }
    
    function claimRewards() public {
        require(checkRewards(_msgSender()) > 0, "CrankCoin: You have zero rewards to claim");
        uint256 _rewards = _rewardsEarned[_msgSender()];
        
        _rewardsEarned[_msgSender()] = 0;
        
        uint256 _tax = (_rewards * 5) / 100;
        uint256 _totalRewards = _rewards - _tax;
        
        _balances[address(this)] += _tax;
        _transfer(address(this), _msgSender(), _totalRewards);
    }
    
    function checkRewards(address account) public view returns(uint256) {
        uint256 _rewards = _rewardsEarned[account];
        if(_rewards == 0) return _rewards;
        
        uint256 _tax = (_rewards * 10) / 100;
        uint256 _finalRewardsBalance = _rewards - _tax;
        return _finalRewardsBalance;
    }
    
    function calculateLockGains(uint256 _amount) public pure returns(uint256) {
        uint256 _rewards = (_amount * 20) / 100;
        return _rewards;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual returns(uint256, uint256) {
        uint _tax = (amount * 5) / 100;
        uint _availableBalance = amount - _tax;
        return (_availableBalance, _tax);
    }
}