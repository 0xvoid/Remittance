
pragma solidity ^0.4.8;

contract Remittance {
 
    address public contractOwner;
    uint    public contractOwnerCommission = 0; //for now 0
    uint    public ownerBank;
    bool    public isRunning;
    uint    public duration = 10; //for now fixed
    enum    RemitStatus {None, Deposited, Withdrawn, Refunded }
    
    modifier onlyOwner {
         require (msg.sender == contractOwner);
         _;
    }

    modifier onlyWhenLive {
        require (isRunning == true);
        _;
    }
    
    struct RemitStruct {
       address  exchanger;
       uint     amount;
       uint     expiryBlock;
       uint     commissionCut;
       bytes32  passString;
    }
    
    struct DepositorStateStruct {
       uint256                          nonce;
       mapping( bytes32 => RemitStatus) remitStates;
    }
    
    mapping(bytes32 => RemitStruct)             public RemitDataStore;
    mapping(address => DepositorStateStruct)    public DepositorDataStore;
    
    event LogSuccessfullyDeposited  (address indexed depositor, address indexed exchanger,  uint amount);
    event LogSuccessfullyPaidOut    (address indexed payedAddress, uint payout, RemitStatus payoutType);
 
    function  Remittance()  
        public         
    { 
        contractOwner   = msg.sender;
        isRunning       = true;
    }
    
    function Deposit(address _exchanger, bytes32 _remitString)
        public 
        payable
        onlyWhenLive
        returns (bool success, bytes32 remitId)
    {
        require (msg.value  >  contractOwnerCommission); //TODO: ?before fail, log an event to notify insufficency
        require (msg.sender != 0);
        require ( _exchanger  != 0);
                        
        uint  currentNonce = DepositorDataStore[msg.sender].nonce;
        uint nextNonce = currentNonce + 1;
         
         //TODO: find a less expensive  method to generate Id here        
        bytes32 newDepositId = keccak256(msg.sender, nextNonce); 

        DepositorDataStore[msg.sender].nonce = nextNonce;
        DepositorDataStore[msg.sender].remitStates[newDepositId]  = RemitStatus.Deposited;
       
        uint depositAmount = msg.value - contractOwnerCommission;
       
        RemitStruct memory newRemit;
        newRemit.exchanger = _exchanger;
        newRemit.amount = depositAmount;
        newRemit.commissionCut = contractOwnerCommission;
        newRemit.expiryBlock = duration + block.number; 
        //  _remitString = computed offline  as  keccak256(exchangerAddress, keccak256(receiverSecret))
        newRemit.passString = _remitString; 
        RemitDataStore[newDepositId] = newRemit;
        
        LogSuccessfullyDeposited(msg.sender, newRemit.exchanger,  newRemit.amount);
        
        return (true, newDepositId);
    }
    
    function withdraw(bytes32 _remitId, bytes32 _password, address _depositor)
        public
        onlyWhenLive
        returns (bool success)
    {
        //exchanger only
        require(RemitDataStore[_remitId].exchanger == msg.sender);
        
        //check depositor exists
        require(DepositorDataStore[_depositor].nonce != 0);
        
        //check remit has been already withdrawn /refunded
        require(DepositorDataStore[_depositor].remitStates[_remitId] == RemitStatus.Deposited);
        
        //check remit withdrawal has not expired
        require(RemitDataStore[_remitId].expiryBlock >=  block.number);
        
        //check secrets match
        //Here _password = computed offline as keccak256(receiverSecret)
        //TODO: Test!
        require(RemitDataStore[_remitId].passString == keccak256(msg.sender, _password) );
        //LogPasswordError();
        
        //Pay out withdrawal
        uint withdrawAmount = RemitDataStore[_remitId].amount;
        uint remitCommissionCut = RemitDataStore[_remitId].commissionCut;
        
        if(remitCommissionCut > 0) {paySelf(remitCommissionCut);}
        
        DepositorDataStore[_depositor].remitStates[_remitId] = RemitStatus.Withdrawn;  //re-entrancy prevention
        msg.sender.transfer (withdrawAmount);
        
        LogSuccessfullyPaidOut(msg.sender, withdrawAmount, RemitStatus.Withdrawn);
        
        return true;
    }
    
    function refund(bytes32 _remitId)
        public
        onlyWhenLive 
        returns (bool success)
    {
        //Only despositor who has already deposited once
        require(DepositorDataStore[msg.sender].nonce != 0);
        
        //Only unclaimed deposit can be refunded
        require( DepositorDataStore[msg.sender].remitStates[_remitId] == RemitStatus.Deposited);
        
        //only a remit that has its Withdraw period expired
        require(RemitDataStore[_remitId].expiryBlock <  block.number); //? Log an event here
        
        //Payout refund
        uint refundAmount = RemitDataStore[_remitId].amount;
        uint remitCommissionCut = RemitDataStore[_remitId].commissionCut;
        
        if(remitCommissionCut > 0) { paySelf(remitCommissionCut); }
        DepositorDataStore[msg.sender].remitStates[_remitId] = RemitStatus.Refunded;  //re-entrancy prevention
       
        msg.sender.transfer (refundAmount); 
        LogSuccessfullyPaidOut(msg.sender, refundAmount, RemitStatus.Refunded);
         
        return true;
    }
    
    
    function paySelf(uint _commissionCut)
        private
    {
        ownerBank += _commissionCut;
    }
    
    function toggleContractState(bool _onOff)
        public 
        onlyOwner
        returns (bool toggleValue)
    {
        return isRunning = _onOff;
    }
    
    function ownerWithdrawal(uint _withdrawAmount) 
        public 
        onlyOwner
        returns (bool success)
    {
        if(ownerBank >_withdrawAmount){
            ownerBank -= _withdrawAmount;
            msg.sender.transfer(_withdrawAmount);
            return true;
        }
        return false; //TODO: Event or meaningful return param
    }
    
     function killMe()
        public
        onlyOwner
    {
        selfdestruct(contractOwner);
    }
    
    function () public {revert();}    
}
