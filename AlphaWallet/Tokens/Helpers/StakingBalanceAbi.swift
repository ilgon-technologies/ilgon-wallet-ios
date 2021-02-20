//
//  StakingBalanceAbi.swift
//  AlphaWallet
//
//  Created by Jili Bernadett on 2021. 02. 26..
//

import Foundation

let stakingBalanceABI  =
"""
 [{
 "inputs": [
 {
 "internalType": "address", "name": "a",
 "type": "address"
 }
 ],
 "name": "getUserDeposits","outputs": [
 {
 "internalType": "uint256","name": "",
 "type": "uint256"
 }
 ],
 "type": "function"
 }]
"""
