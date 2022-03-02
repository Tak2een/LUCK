// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

import "./SafeMath.sol";
import "./Strings.sol";

interface Interface { 

    // basic functions

    function totalsupplys() external view returns (uint256); // 총 발행량 조회

    function balanceOf(address account) external view returns (uint256); // 잔고 조회 함수

    function allowance(address owner, address spender) external view returns (uint256); // allowance 조회

    function transfer(address _to, uint256 numTokens) external returns (bool); // transfer

    function approve(address delegate, uint256 numTokens) external returns (bool); // 지분 증명

    function transferFrom(address _from, address _to, uint256 numTokens) external returns (bool); // claim

    //// staking 

    function getLuckStakingOver() external view returns (uint256); // staking 기준 반환

    function setLuckStakingOver(uint256 n) external; // staking 기준 설정
   
    // tax functions

    function setTransactiontaxpool(address addr) external; // transfer tax pool 설정

    function setClaimtaxpool(address addr) external; // claim tax pool 설정
    
    function getTransactiontaxpool() external view returns(address); // transfer pool 주소 반환

    function getClaimtaxpool() external view returns(address); // claim pool 주소 반환

    function setTransactionFeePercent(uint8 percent) external; // transfer tax rate 설정

    function setClaimFeePercent(uint8 percent) external; // claim tax rate 설정

    function getTransactionFeerate() external view returns(uint8 max, uint8 min, uint8 fee); // transfer tax rate 반환

    function getClaimFeerate() external view returns(uint8 max, uint8 min, uint8 fee); // cliam tax rate 반환

    // blacklist

    function addBlackList(address addr) external; // blacklist 추가

    function deleteBlackList(address addr) external; // blacklist 제거

    function getBlacklist() external view returns (address [] memory); // blacklist 목록 조회

    // _isExcludedFromFee

    function addExcludedFromFee(address addr) external; // tax 면제 리스트 추가

    function deleteExcludedFromFee(address addr) external; // tax 면제 리스트 제거

    function getisExcludedfromFeelist() external view returns(address [] memory); // tax 면제 리스트 목록 조회

    // Transfer amount free

    function addTransferamountfree(address addr) external; // 거래량 제한 면제 리스트 추가

    function deleteTransferamountfree(address addr) external; // 거래량 제한 면제 리스트 제거

    function getTransferamountfreelist() external view returns(address [] memory); // 거래량 제한 면제 리스트 목록 조회

    function setMinimumTransferAmount(uint256 amount) external; // 최소 거래량 설정

    function setMaximumTransferAmount(uint256 amount) external; // 최대 거래량 설정

    function getMinimumTransferAmount() external view returns (uint256); // 최소 거래량 반환

    function getMaximumTransferAmount() external view returns (uint256); // 최대 거래량 반환

    // Transfer time free

    function addTransfertimefree(address addr) external; // 거래 당 최소 대기 시간 면제 리스트 추가
 
    function deleteTransfertimefree(address addr) external; // 거래 당 최소 대기 시간 면제 리스트 제거

    function getTransfertimefreelist() external view returns(address [] memory); // 거래 당 최소 대기 시간 면제 리스트 목록 조회

    function setTransferMinimumTime(uint8 sec) external; // 거래 대기 시간 설정

    function getTransferMinimumTime() external view returns(uint128); // 거래 간 대기시간 반환

    // lock

    function lock(uint256 sec) external; // 특정 시간동안 lock
    
    function unlock() external; // lock 해제

    function addlockfree(address addr) external; // lock 면제되는 지갑들 리스트 추가

    function deletelockfree(address addr) external; // lock 면제되는 지갑들 리스트 제거

    function getlockfreelist() external view returns(address [] memory); // lock 면제되는 지갑들 리스트 목록 조회

    function getUnlockTime() external view returns (uint256); 

    function gettimestamp() external view returns (uint256); // block의 timestamp 반환
}


contract LUCK is Interface {

    struct Tax {
        uint8 max; // %로 작성
        uint8 min; // %로 작성
        uint8 fee; // %로 작성
    }

    // logging for token fludity

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    using SafeMath for uint256;

    string public name = "Luck";
    string public symbol = "LUCK";

    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;

    mapping(address => bool) private blacklist; // blacklist memory
    address[] public blacklistkey;

    mapping(address => bool) private _isExcludedFromFee; // address memory for transfer tax free 
    address[] public _isExcludedFromFeekey;

    mapping(address => bool) private _Transferfree; // address memmory for transfer amount free
    address[] public _Transferfreekey;

    mapping(address => bool) private _Transfertimefree; // address memory for transfer time free
    address[] public _Transfertimefreekey;
    
    mapping(address => bool) private _lockfree; // address memory for lock free
    address[] public _lockfreekey;

    // chase transfer log
    mapping(address => uint256) private lastTransfered; 

    // token options
    uint8 public decimals = 18;
    uint256 public decimals_m10 = 10 ** decimals;
    uint256 public totalSupply = 100000000000 * decimals_m10; // 1 million tokens
    
    // initialize variable
    address private _owner_address;
    address private _transactionfee_address = 0xff76a3Bf94E88031140C62cb264F7BB8A8eB6706; // 거래 시 모이는 럭 주소
    address private _claimfee_address = 0xff76a3Bf94E88031140C62cb264F7BB8A8eB6706; // 클레임 시 모이는 럭 주소
    address private _booster_address = 0x583031D1113aD414F02576BD6afaBfb302140225; // 부스터 구매 시 모이는 럭 주소
    
    uint256 private _unlockTime;
    uint8 private transferMinimumTime=60; // second
    uint256 private _minimumTransferAmount = 0;
    uint256 private _maximumTransferAmount = totalSupply;

    // Tax
    Tax private claim = Tax(12,0,0); // max, min, fee % 단위로 작성해주시면 됩니다.
    Tax private transaction = Tax(12,0,0);

    // Staking
    address[] public _luckStakingTargets; // staking target memory
    uint256 private _luckStakingOver = 1000000 * decimals_m10; // 100만개 이상있는 사람한테 분배하기 위함

    // Initiallize Wallet
    // Wallet public Marketing = Wallet(주소, 비율);
    // Wallet public referral = Wallet(주소, 비율);

    constructor(address[] memory addresses, uint32 [] memory portions) {
        
        uint256 addresslength = addresses.length;
        uint256 portionlength = portions.length;

        bool check;
        check = addresslength == portionlength;
        if (!check) require(false,"Error! input lists must have same length.");  // input list들의 길이가 같은지 확인 오입력 방지

        uint32 sum;

        for (uint32 l =0; l < portions.length; l++) {
            sum += portions[l];
        }

        check = sum == 1000000;

        if (!check) require(false,"Error! sum of portions must be 100%."); // portion의 합이 100%가 되는지 확인 오입력 방지

        emit Transfer(address(0), addresses[0], totalSupply);

        for (uint32 i = 0; i < addresses.length; i++) {
            balances[addresses[i]] = totalSupply*portions[i]/1000000;
            _isExcludedFromFee[addresses[i]] = true; // 초기 생성 지갑들의 권한 부여
            _Transferfree[addresses[i]] = true;
            _Transfertimefree[addresses[i]] = true;
            _lockfree[addresses[i]] = true;
            _isExcludedFromFeekey.push(addresses[i]);
            _Transferfreekey.push(addresses[i]);
            _Transfertimefreekey.push(addresses[i]);
            _lockfreekey.push(addresses[i]);

            if (i > 0) {
                emit Transfer(addresses[0], addresses[i], totalSupply*portions[i]/1000000);
            }
        }

        _owner_address = msg.sender;
        _isExcludedFromFee[msg.sender] = true;

        _isExcludedFromFee[_transactionfee_address] = true;
        _isExcludedFromFeekey.push(_transactionfee_address);
        _isExcludedFromFee[_claimfee_address] = true;
        _isExcludedFromFeekey.push(_claimfee_address);
        _isExcludedFromFee[_booster_address] = true;
        _isExcludedFromFeekey.push(_booster_address);
        
    }

    modifier onlyOwner() {
        require(_owner_address == msg.sender, "Error! Ownable: caller is not the owner");
        _;
    }

    function totalsupplys() public override view returns (uint256) {
        return totalSupply;
    }

    function balanceOf(address account) public override view returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) public override view returns (uint) {
        return allowed[owner][spender];
    }
    
    function transfer(address _to, uint256 numTokens) public returns (bool success) {
        
        bool check;
        // 1. balance section
        require(balances[msg.sender] >= numTokens,Strings.strConcat("Not enough LUCK in your wallet, You have", Strings.toString(balances[msg.sender]),"LUCK.")); // check balance
        
        // 2. blacklist section
        require(!blacklist[msg.sender],"Your wallet address is blacklisted.");  // check blacklisted
        require(!blacklist[_to],"This wallet address is blacklisted.");

        // 3. transfer amount section
        if (_Transferfree[msg.sender]) {} // check transfer amount free
        else{
            check = numTokens >= _minimumTransferAmount;
            if (!check) require(false,Strings.strConcat("Minimum transferable token is ",Strings.toString(_minimumTransferAmount)," LUCK."));

            check = numTokens <= _maximumTransferAmount;
            if (!check) require(false,Strings.strConcat("Maximum transferable token is ",Strings.toString(_maximumTransferAmount)," LUCK."));
        }
        // 4. lock section
        
        if (_lockfree[msg.sender]) {} // check transfer amount free
        else{
            check = block.timestamp >= _unlockTime;
            if(!check) require(false,"LUCK is now under inspection.");
        }

        // 5. transfer time section
        if (_Transfertimefree[msg.sender]) {}
        else{
            if (transferMinimumTime > 0) {
            check = lastTransfered[msg.sender] + transferMinimumTime < block.timestamp;
            if (!check) require(false, 
                Strings.strConcat("You can transfer LUCK after ",Strings.toString(
                    lastTransfered[msg.sender] + transferMinimumTime - block.timestamp
                )," seconds.") 
            );

            lastTransfered[msg.sender] = block.timestamp;
            }   
        }
        
        // 6. tax section
        uint256 tax = 0;

        if(_isExcludedFromFee[msg.sender] || _isExcludedFromFee[_to]){
        }else{
            tax = numTokens / 100 * transaction.fee;
        }

        uint256 _real_value = numTokens - tax;

        balances[msg.sender] -= numTokens;

        if (tax>0) {
            balances[_transactionfee_address] += tax;
            emit Transfer(msg.sender, _transactionfee_address, tax);
        }

        balances[_to] += _real_value;
        emit Transfer(msg.sender, _to, _real_value);

        // classifyStakingTarget(msg.sender);
        // classifyStakingTarget(_to);

        return true;
    }

    function approve(address delegate, uint256 numTokens) public override returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 numTokens) public override returns (bool) {

        // 1. balance & approve section
        require(numTokens <= balances[_from], "Not enough LUCK in claim pool, please retry later.");
        require(numTokens <= allowed[_from][msg.sender], Strings.strConcat("Not enough LUCK is allowed for you, You allowed only", Strings.toString(allowed[_from][msg.sender]),"LUCK."));
        
        // 2. blacklist section
        require(!blacklist[msg.sender],"Your wallet address is blacklisted.");
        
        // 3. tax section
        uint256 tax = 0;
        if(_isExcludedFromFee[msg.sender] || _isExcludedFromFee[_to]){
        }else{
            tax = numTokens / 100 * claim.fee;
        }

        uint256 _real_value = numTokens - tax;

        balances[_from] = balances[_from].sub(numTokens);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(numTokens);

        if (tax>0) {
            balances[_claimfee_address] += tax;
            emit Transfer(_from, _claimfee_address, tax);
        }

        balances[_to] = balances[_to].add(_real_value);
        emit Transfer(_from, _to, _real_value);
        return true;
    }

    //// staking

    function getLuckStakingOver() public override view returns (uint256) {
        return _luckStakingOver;
    }

    function setLuckStakingOver(uint256 n) onlyOwner public override {
        _luckStakingOver = n;
    }

    // tax functions

    function setTransactiontaxpool(address addr) public override {
        _transactionfee_address = addr;
    }

    function setClaimtaxpool(address addr) public override {
        _claimfee_address = addr;
    }
    
    function getTransactiontaxpool() public override view returns(address) {
        return _transactionfee_address;
    }

    function getClaimtaxpool() public override view returns(address) {
        return _claimfee_address;
    }

    function setTransactionFeePercent(uint8 percent) onlyOwner public override {
        require(transaction.max >= percent,Strings.strConcat("Error! maximum transaction fee percent is",Strings.toString(transaction.max),'.'));
        require(transaction.min <= percent,Strings.strConcat("Error! minimum transaction fee percent is",Strings.toString(transaction.min),'.'));

        transaction.fee = percent;
    }
    
    function setClaimFeePercent(uint8 percent) onlyOwner public override {
        require(claim.max >= percent,Strings.strConcat("Error! maximum claim fee percent is",Strings.toString(claim.max),'.'));
        require(claim.min <= percent,Strings.strConcat("Error! minimum claim fee percent is",Strings.toString(claim.min),'.'));

        claim.fee= percent;
    }

    function getTransactionFeerate() public view returns(uint8 max, uint8 min, uint8 fee) {
        max = transaction.max;
        min = transaction.min;
        fee = transaction.fee;
    }

    function getClaimFeerate() public view returns(uint8 max, uint8 min, uint8 fee) {
        max = claim.max;
        min = claim.min;
        fee = claim.fee;
    }

    // blacklist

    function addBlackList(address addr) onlyOwner public {
        blacklist[addr] = true;
        bool inkey = false;
        for (uint256 i = 0; i < blacklistkey.length; i++) {
            if (blacklistkey[i] == addr) {
                inkey = true;
            }
        }

        require(!inkey, "This address is already enrolled in blacklist.");

        if (inkey == false) {
            blacklistkey.push(addr);
        }

    }
    
    function deleteBlackList(address addr) onlyOwner public {
        bool success = false;
        delete blacklist[addr];
        
        for (uint256 i = 0; i < blacklistkey.length; i++) {
            if (blacklistkey[i] == addr) {
                if (i == blacklistkey.length-1) {
                    blacklistkey.pop();
                    success = true;
                }
                else {
                    blacklistkey[i] = address(0);
                    success = true;
                }
            }
        }

        require(success, 'This address not in Blacklist.');

    }

    function getBlacklist() onlyOwner public override view returns(address [] memory) {
        return blacklistkey;
    }

    // _isExcludedFromFee

    function addExcludedFromFee(address addr) onlyOwner public override {
        _isExcludedFromFee[addr] = true;
        bool inkey = false;
        for (uint256 i = 0; i < _isExcludedFromFeekey.length; i++) {
            if (_isExcludedFromFeekey[i] == addr) {
                inkey = true;
            }
        }

        require(!inkey, "This address is already no fee address.");

        if (inkey == false) {
            _isExcludedFromFeekey.push(addr);
        }
    }

    function deleteExcludedFromFee(address addr) onlyOwner public override {
        
        bool success = false;
        delete _isExcludedFromFee[addr];

        for (uint256 i = 0; i < _isExcludedFromFeekey.length; i++) {
            if (_isExcludedFromFeekey[i] == addr) {
                if (i == _isExcludedFromFeekey.length-1) {
                    _isExcludedFromFeekey.pop();
                    success = true;
                }
                else {
                    _isExcludedFromFeekey[i] = address(0);
                    success = true;
                }
            }
        }
        require(success, 'This address not in no fee list.');
    }

    function getisExcludedfromFeelist() onlyOwner public override view returns(address [] memory) {
        return _isExcludedFromFeekey;
    }

    // Transfer amount free

    function addTransferamountfree(address addr) onlyOwner public override {
        _Transferfree[addr] = true;
        bool inkey = false;
        for (uint256 i = 0; i < _Transferfreekey.length; i++) {
            if (_Transferfreekey[i] == addr) {
                inkey = true;
            }
        }

        require(!inkey, "This address is already transfer amount free address.");

        if (inkey == false) {
            _Transferfreekey.push(addr);
        }
    }

    function deleteTransferamountfree(address addr) onlyOwner public override {
        bool success = false;
        delete _Transferfree[addr];

        for (uint256 i = 0; i < _Transferfreekey.length; i++) {
            if (_Transferfreekey[i] == addr) {
                if (i == _Transferfreekey.length-1) {
                   _Transferfreekey.pop();
                    success = true;
                }
                else {
                    _Transferfreekey[i] = address(0);
                    success = true;
                }
            }
        }
        require(success, 'This address not in no fee list.');
    }

    function setMinimumTransferAmount(uint256 amount) onlyOwner public override {
        _minimumTransferAmount = amount;
    }

    function setMaximumTransferAmount(uint256 amount) onlyOwner public override {
        _maximumTransferAmount = amount;
    }

    function getMinimumTransferAmount() public override view returns (uint256) {
        return _minimumTransferAmount;
    }

     function getMaximumTransferAmount() public override view returns (uint256) {
        return _maximumTransferAmount;
    }

    function getTransferamountfreelist() public override view returns(address [] memory) {
        return _Transferfreekey;
    }

    // Transfer time free

    function addTransfertimefree(address addr) onlyOwner public {
        _Transfertimefree[addr] = true;
        bool inkey = false;
        for (uint256 i = 0; i < _Transfertimefreekey.length; i++) {
            if (_Transfertimefreekey[i] == addr) {
                inkey = true;
            }
        }

        require(!inkey, "This address is already transfer time free address.");

        if (inkey == false) {
            _Transfertimefreekey.push(addr);
        }
    }
 
    function deleteTransfertimefree(address addr) onlyOwner public {
        bool success = false;
        delete _Transfertimefree[addr];

        for (uint256 i = 0; i < _Transfertimefreekey.length; i++) {
            if (_Transfertimefreekey[i] == addr) {
                if (i == _Transfertimefreekey.length-1) {
                   _Transfertimefreekey.pop();
                    success = true;
                }
                else {
                    _Transfertimefreekey[i] = address(0);
                    success = true;
                }
            }
        }
        require(success, 'This address not in transfer time free list.');
    } 

    function getTransfertimefreelist() onlyOwner public override view returns(address [] memory) {
        return _Transfertimefreekey;
    } 

    function setTransferMinimumTime(uint8 sec) onlyOwner public override {
        transferMinimumTime = sec;
    }

    function getTransferMinimumTime() public override view returns(uint128) {
        return transferMinimumTime;
    }

    // lock

    function lock(uint256 sec) onlyOwner public override {
        _unlockTime = block.timestamp + sec;
    }
 
    function unlock() onlyOwner public override {
        // require(now > _unlockTime , "Contract is locked until 7 days");
        _unlockTime = block.timestamp;
    }

    function addlockfree(address addr) onlyOwner public {
         _lockfree[addr] = true;
        bool inkey = false;
        for (uint256 i = 0; i < _lockfreekey.length; i++) {
            if (_lockfreekey[i] == addr) {
                inkey = true;
            }
        }

        require(!inkey, "This address is already lock free address.");

        if (inkey == false) {
            _lockfreekey.push(addr);
        }
    }

    function deletelockfree(address addr) onlyOwner public {
        bool success = false;
        delete _lockfree[addr];

        for (uint256 i = 0; i < _lockfreekey.length; i++) {
            if (_lockfreekey[i] == addr) {
                if (i == _lockfreekey.length-1) {
                   _lockfreekey.pop();
                    success = true;
                }
                else {
                    _lockfreekey[i] = address(0);
                    success = true;
                }
            }
        }
        require(success, 'This address not in lock free list.');
    }

    function getlockfreelist() onlyOwner public override view returns(address [] memory){
        return _lockfreekey;
    }

    function getUnlockTime() public override view returns (uint256) {
        return _unlockTime;
    }

     function gettimestamp() public override view returns (uint256) {
        return block.timestamp;
    }
} 