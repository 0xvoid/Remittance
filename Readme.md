Small Prokect : Remittance 

Aim: Allow ether to be exchanged to local currency via an intermdiary exchanger.

Process: 
	Depositor 
		Deposits ether in to the smart contract
		sends the exchanger's address as input 
		sends the receiver their secret password via a non-blockchain method
		sends an offline hashed password as inputs to desposit using the exchanger's address and receiver's secret 
		Is only allowed refunds after the remit expiry block has passed		
		receivers a remitId on successful deposit
		sends exchanger the remitId

		when remit expires and funds havenot been withdrawn by the exchanger : 
			depsoitor calls refund with the remit id
			contract sets remit amount to 0 and sends depositor the funds

	Exchanger
		receives remitId from depositor
		Gives local currency equivalent of deposited ether to receiver
		receives secret from receiver
		Computes offline the hash of the receiver's secret
		Calls withdraw on contract using the remitId and hashed secret before the remit expires
		contract sets remit amount to 0 and sends exchanger the funds

	owner
		can withdraw commsion funds by specifying the amount
		can pause/ un-pause contract

	contract 
		On deposit  :  updates depositor nonce,
						contract creates remit with Id, expiry date, remit password string
						adds commision to owner - emits event

		On withdraw : 	checks remit has not expired, 
						checks password is correct with one in remit storage,
						sends funds to exhanger,
						emits event

		On refund   :	checks  remit has expired,
					  	checks caller is despositor with the correct remitId,
						sends funds depsoitor, 
						emits event


