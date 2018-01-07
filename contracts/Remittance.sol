
pragma solidity ^0.4.8;

contract Remittance {
 
    address public contractOwner;
    uint    public contractOwnerCommision = 0; //for now 0
    uint    public duration;
    enum    RemitStatusChoices {Deposited, Withdrawn, Refunded }
    
    struct RemitStruct {
       address exchanger;
       address receiver; 
       address depositor;
       uint amount;
       uint remitExpiryBlock;
       
       uint blockStamp;
       RemitStatusChoices remitStatus;
    }
    
    mapping(address => RemitStruct) public RemitDataStore;
    
    event LogRemitDeposited(address indexed depositor, address indexed exchanger, address indexed receiver, uint blockStamp, uint amount);
    event LogRemitPayOut(address indexed payedAddress, address indexed receiver, uint blockStamp, uint payout, RemitStatusChoices payoutType);
 
    function  Remittance(address _owner, uint _remitDuration)  
        public 
    { 
        contractOwner = _owner;
        duration =  _remitDuration;
    }
    
    function Deposit(address _exchanger, address _receiver)
        public 
        payable
        returns (bool success)
    {
        require (msg.sender != 0);
        require (msg.value  != 0);
        require ( _receiver  != 0);
        require ( _exchanger  != 0);
        
        uint currentBlock = block.number;
        uint expiryBlock = duration + currentBlock;
        
        require(RemitDataStore[msg.sender].remitStatus  == RemitStatusChoices.Deposited);
        require( (RemitDataStore[msg.sender].blockStamp != currentBlock)  &&  (RemitDataStore[msg.sender].receiver != _receiver) );
        //LogDelayDepositIssued();
        
        RemitStruct memory newRemit;
        newRemit.exchanger = _exchanger;
        newRemit.receiver = _receiver;
        newRemit.depositor = msg.sender;
        newRemit.amount = msg.value;
        newRemit.remitExpiryBlock = expiryBlock;
        newRemit.blockStamp = currentBlock;
        newRemit.remitStatus = RemitStatusChoices.Deposited;
        RemitDataStore[newRemit.depositor ] = newRemit;
        
        LogRemitDeposited(newRemit.depositor, newRemit.exchanger, newRemit.receiver, newRemit.blockStamp, newRemit.amount);
        
        return true;
    }
    
    
    function Withdraw(byte password, address _depositor, address _receiver)
        public
        payable
        returns (bool success)
    {
        //fail fast
        require(RemitDataStore[_depositor].exchanger == msg.sender);
        
        require ( _receiver   != 0);
        require ( _depositor  != 0);
        //check remit has been already withdrawn /refunded
        require(RemitDataStore[_depositor].amount != 0  );
        
        //check remit withdrawal has not expired
        require(RemitDataStore[msg.sender].remitExpiryBlock <=  block.number);
        
        //only exchanger allowed to Withdraw
        require(RemitDataStore[_depositor].exchanger == msg.sender);
        require(RemitDataStore[_depositor].receiver == _receiver );
        uint withdrawAmount = RemitDataStore[_depositor].amount;
        
        //TODO: check secrets checkout
        require(password != '');
        //LogPasswordError();
        
        
        //Pay out withdrawal
        RemitDataStore[_depositor].remitStatus = RemitStatusChoices.Withdrawn;
        RemitDataStore[_depositor].amount = 0; //reentrancy prevention
        uint payout = withdrawAmount - contractOwnerCommision;
        msg.sender.transfer (payout); 
        LogRemitPayOut(msg.sender, _receiver, RemitDataStore[_depositor].blockStamp, payout, RemitStatusChoices.Withdrawn);
        
        return true;
    }
    
    function Refund(address _exchanger, address _receiver)
        public 
        payable
        returns (bool success)
    {
        require (msg.sender != 0);
        require ( _receiver  != 0);
        require ( _exchanger  != 0);
        
        //Only depositor can claim Refund
        require(RemitDataStore[msg.sender].depositor == msg.sender);
        
        //Challenge remit refund period is correct
        require(RemitDataStore[msg.sender].remitExpiryBlock >  block.number);
        
        //Payout refund
        uint withdrawAmount = RemitDataStore[msg.sender].amount;
        RemitDataStore[msg.sender].amount = 0; //reentrancy prevention
        
        RemitDataStore[msg.sender].remitStatus = RemitStatusChoices.Refunded;
        uint payout = withdrawAmount - contractOwnerCommision;
        msg.sender.transfer (payout); 
        LogRemitPayOut(msg.sender, _receiver, RemitDataStore[msg.sender].blockStamp, payout, RemitStatusChoices.Refunded);
         
        return true;
    }
    
    
     function killMe()
        public
    {
        require (msg.sender == contractOwner);
        selfdestruct(contractOwner);
    }
    
    function () public {}
    
}
