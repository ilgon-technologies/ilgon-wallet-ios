// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import web3swift
import PromiseKit

class GetNativeCryptoCurrencyBalanceCoordinator {
    let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getBalance(
        for address: AlphaWallet.Address,
        completion: @escaping (ResultResult<Balance, AnyError>.t) -> Void
    ) {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address)))
        firstly {
            Session.send(request)
        }.done {
            completion(.success($0))
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }
    
    func getStakingBalance(
            for address: AlphaWallet.Address,
            completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void
    ) {
        let functionName = "getUserDeposits"
        
        let contract = AlphaWallet.Address(uncheckedAgainstNullAddress:
            server == RPCServer.main ?
                                            getStringProperty(for: "MAIN_STAKING_CONTRACT_ADDRESS") :
                                            getStringProperty(for: "SECONDARY_STAKING_CONTRACT_ADDRESS")
        )!
        callSmartContract(withServer: server, contract: contract,
                          functionName: functionName, abiString: stakingBalanceABI, parameters: [address.eip55String] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout).done { balanceResult in
            if let balanceWithUnknownType = balanceResult["0"] {
                let string = String(describing: balanceWithUnknownType)
                if let balance = BigInt(string) {
                    completion(.success(balance))
                } else {
                    completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
                }
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
            }
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }
}
