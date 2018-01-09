var Remittance = artifacts.require("./Remittance.sol");

contract("Remittance", function(accounts) {
	var remitContract;
	var owner = accounts[0];
	var depositor = accounts[1];
	var exchanger = accounts[2];
	var receiver = accounts[3];
	var notInvited = accounts[4];
	var remitDuration = 5;	

	beforeEach(function(){
		return Remittance.new({from: owner})
		.then(instance =>	remitContract = instance);		
	});

	//constructor 
	it("should be owned by owner", function(){
		return remitContract.contractOwner({from: notInvited})
		.then(function(_actualOwner){
			assert.strictEqual(_actualOwner, owner,"contract is not owned by owner"); 		
		});
	});

	it("owner can pause entire contract", function (){
		return remitContract.toggleContractState(false, {from: owner})
		.then( function(txn){
			return remitContract.isRunning({from: owner});		
		})
		.then(function (_result){
			assert.strictEqual(_result,false, "contract running state not changed by owner");
		});
	});
});