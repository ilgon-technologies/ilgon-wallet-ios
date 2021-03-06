// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Moya

enum AlphaWalletService {
    case formerPriceOfEth(config: Config, date: Date)
    case priceOfEth(config: Config)
    case priceOfDai(config: Config)
    case getTransactions(config: Config, server: RPCServer, address: AlphaWallet.Address, startBlock: Int, endBlock: Int, sortOrder: SortOrder)
    case register(config: Config, device: PushDevice)
    case unregister(config: Config, device: PushDevice)
    case marketplace(config: Config, server: RPCServer)
    case gasPriceEstimate
    case oneInchTokens(config: Config)

    enum SortOrder: String {
        case asc
        case desc
    }
}

extension AlphaWalletService: TargetType {
    var baseURL: URL {
        switch self {
        case .getTransactions(_, let server, _, _, _, _):
            return server.transactionInfoEndpoints
        case .priceOfEth(let config), .priceOfDai(let config):
            return config.ilgonPriceInfo
        case .formerPriceOfEth(let config, let date):
            return URL(string: "\(config.ilgonPriceInfo)?timestamp=\(Int64(date.timeIntervalSince1970))")!
        case .register(let config, _), .unregister(let config, _):
            return config.priceInfoEndpoints
        case .marketplace(let config, _):
            return config.priceInfoEndpoints
        case .gasPriceEstimate:
            return URL(string: Constants.gasNowEndpointBaseUrl)!
        case .oneInchTokens(let config):
            return config.oneInch
        }
    }

    var path: String {
        switch self {
        case .getTransactions(_, let server, _, _, _, _):
            switch server {
            case .main, .classic, .callisto, .kovan, .ropsten, .custom, .rinkeby, .poa, .sokol, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet:
                return "/api"
            }
        case .register:
            return "/push/register"
        case .unregister:
            return "/push/unregister"
        case .priceOfEth, .formerPriceOfEth:
            return "" // /api/v3/coins/markets"
        case .priceOfDai:
            return "/api/v3/coins/markets"
        case .marketplace:
            return "/marketplace"
        case .gasPriceEstimate:
            return "/api/v3/gas/price"
        case .oneInchTokens:
            return "/v1.1/tokens"
        }
    }

    var method: Moya.Method {
        switch self {
        case .getTransactions: return .get
        case .register: return .post
        case .unregister: return .delete
        case .priceOfEth: return .get
        case .formerPriceOfEth: return .get
        case .priceOfDai: return .get
        case .marketplace: return .get
        case .gasPriceEstimate: return .get
        case .oneInchTokens: return .get
        }
    }

    var task: Task {
        switch self {
        case .getTransactions(_, let server, let address, let startBlock, let endBlock, let sortOrder):
            switch server {
            case .main, .kovan, .ropsten, .rinkeby, .goerli:
                return .requestParameters(parameters: [
                    "module": "account",
                    "action": "txlist",
                    "address": address,
                    "startblock": startBlock,
                    "endblock": endBlock,
                    "sort": sortOrder.rawValue,
                    "apikey": Constants.Credentials.etherscanKey,
                ], encoding: URLEncoding())
            case .classic, .callisto, .custom, .poa, .sokol, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet:
                return .requestParameters(parameters: [
                    "module": "account",
                    "action": "txlist",
                    "address": address,
                    "startblock": startBlock,
                    "endblock": endBlock,
                    "sort": sortOrder.rawValue,
                ], encoding: URLEncoding())
            }
        case .register(_, let device):
            return .requestJSONEncodable(device)
        case .unregister(_, let device):
            return .requestJSONEncodable(device)
        case .priceOfEth, .formerPriceOfEth:
            return .requestPlain
        case .priceOfDai:
            return .requestParameters(parameters: [
                "vs_currency": "USD",
                "ids": "dai",
            ], encoding: URLEncoding())
        case .marketplace(_, let server):
            return .requestParameters(parameters: ["chainID": server.chainID], encoding: URLEncoding())
        case .gasPriceEstimate:
            return .requestPlain
        case .oneInchTokens:
            return .requestPlain
        }
    }

    var sampleData: Data {
        return Data()
    }

    var headers: [String: String]? {
        switch self {
        case .getTransactions(_, let server, _, _, _, _):
            switch server {
            case .main, .classic, .callisto, .kovan, .ropsten, .custom, .rinkeby, .poa, .sokol, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet:
                return [
                    "Content-type": "application/json",
                    "client": Bundle.main.bundleIdentifier ?? "",
                    "client-build": Bundle.main.buildNumber ?? "",
                ]
            }
        case .priceOfEth, .priceOfDai, .register, .unregister, .marketplace, .gasPriceEstimate, .formerPriceOfEth:
            return [
                "Content-type": "application/json",
                "client": Bundle.main.bundleIdentifier ?? "",
                "client-build": Bundle.main.buildNumber ?? "",
            ]
        case .oneInchTokens:
            return nil
        }
    }
}
