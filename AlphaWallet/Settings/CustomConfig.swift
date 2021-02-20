//
//  CustomConfig.swift
//  AlphaWallet
//
//  Created by Jili Bernadett on 2021. 01. 27..
//

import Foundation
import BigInt

func getStringProperty(for name: String) -> String {
    return Bundle.main.object(forInfoDictionaryKey: name) as! String
}

func getIntProperty(for name: String) -> Int {
    return Int(Bundle.main.object(forInfoDictionaryKey: name) as! String)!
}

let CUSTOM_GAS_PRICE: BigInt = 10000000000000
