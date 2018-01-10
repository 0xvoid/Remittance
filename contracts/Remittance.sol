
pragma solidity ^0.4.8;

contract Remittance {
 
    address public      owner;
    uint    constant public    ownerCommission = 0; //for now 0
    uint    public      ownerBank;
    bool    public      isStopped;
    uint    public      duration = 10; //for now fixed
    
    
    modifier onlyOwner {
         require (msg.sender == owner);
         _;
    }

    modifier onlyWhenLive {
        require (isStopped == true);
        _;
    }
    
    struct RemitStruct {
       address  depositor;
       uint     amount;
       uint     expiryBlock;       
       bytes32  passString;
    }
        
    mapping(bytes32 => RemitStruct)     public RemitDataStore;
    mapping(address => uint)            public DepositorDataStore;
    
    event LogSuccessfullyDeposited  (bytes32 remitId, uint desposit, address indexed depositor, address indexed exchanger );
    event LogSuccessfullyWithdrawn  (bytes32 remitId, uint payout, address indexed withdrawAddress);
    event LogSuccessfullyRefunded   (bytes32 remitId, uint payout, address indexed refundAddress);
    event LogCommisionCollected     (address indexed depositor, uint amount);
    event LogOwnerWithdrwal         (uint withdrawAmount);
    event LogContractStateChanged   (bool isStopped);
 
    function  Remittance()  
        public         
    { 
        owner   = msg.sender;
    }
    
    function Deposit(address _exchanger, bytes32 _remitString)
        public 
        payable
        onlyWhenLive
        returns (bool success, bytes32 remitId)
    {
        require (msg.value  >  ownerCommission);
        require (msg.sender != 0);
        require ( _exchanger  != 0);
                        
        uint  currentNonce = DepositorDataStore[msg.sender];
        uint nextNonce = currentNonce + 1;
        bytes32 newDepositId = keccak256(msg.sender, nextNonce);  //TODO: find a less expensive  method to generate Id here        
        DepositorDataStore[msg.sender] = nextNonce;
       
        uint depositAmount = msg.value - ownerCommission;
        ownerBank += ownerCommission; //Pay self here
        LogCommisionCollected(msg.sender, ownerCommission);
       
        RemitStruct memory newRemit  = RemitStruct (msg.sender, depositAmount, duration + block.number, _remitString);
        RemitDataStore[newDepositId] = newRemit;
        // _remitString = computed offline  as web3.utils.soliditySha3('Exchangeraddress', 'shaString' )) where 
        // shaString = web3.utils.soliditySha3(web3.utils.soliditySha3('receiverSecretString') & Exchangeraddress starts with 0x
        
        LogSuccessfullyDeposited(remitId, depositAmount, msg.sender, _exchanger);
        return (true, newDepositId);
    }
    
    function withdraw(bytes32 _remitId, bytes32 _password)
        public
        onlyWhenLive
        returns (bool success)
    {   
        require(RemitDataStore[_remitId].amount != 0);                  //Fail re-entrancy first
        require(RemitDataStore[_remitId].expiryBlock >=  block.number);  //Only remit NOT expired yet
        
        require(RemitDataStore[_remitId].passString == keccak256(msg.sender, _password) );  //check secrets match
        //_password pre-computed offline as web3.utils.soliditySha3('receiverSecretString') 
        
        //Pay out withdrawal
        uint withdrawAmount = RemitDataStore[_remitId].amount;
        RemitDataStore[_remitId].amount = 0; //re-entrancy prevention
        msg.sender.transfer (withdrawAmount);
        
        LogSuccessfullyWithdrawn(_remitId, withdrawAmount, msg.sender);
        return true;
    }
    
    function refund(bytes32 _remitId)
        public
        onlyWhenLive 
        returns (bool success)
    {
        require(RemitDataStore[_remitId].depositor == msg.sender);      //only remit's depositor
        require(RemitDataStore[_remitId].amount != 0);                  //only unclaimed remit
        require(RemitDataStore[_remitId].expiryBlock <  block.number);  //only expired remit
        
        //Payout refund
        uint refundAmount = RemitDataStore[_remitId].amount;
        RemitDataStore[_remitId].amount = 0; //re-entrancy prevention
        msg.sender.transfer (refundAmount); 
        
        LogSuccessfullyRefunded(_remitId, refundAmount, msg.sender);
        return true;
    }
    
        
    function setContractState(bool _onOff)
        public 
        onlyOwner
        returns (bool toggleValue)
    {
        LogContractStateChanged(_onOff);
        return isStopped = _onOff;
    }
    
    function ownerWithdrawal(uint _withdrawAmount) 
        public 
        onlyOwner
        onlyWhenLive
        returns (bool success)
    {
        require(ownerBank >= _withdrawAmount);
        require(ownerBank != 0 );
        ownerBank -= _withdrawAmount;
        msg.sender.transfer(_withdrawAmount);
        
        LogOwnerWithdrwal(_withdrawAmount);
        return true;
    }
    
     function killMe()
        public
        onlyOwner        
    {
        require(isStopped); //prevent mistake of calling this when contract is live
        selfdestruct(owner);
    }
    
    function () public {revert();}    
}
