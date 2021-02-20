// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct ConfirmPaymentDetailsViewModel {
    private let transaction: PreviewTransaction
    private let currentBalance: BalanceProtocol?
    private let currencyRate: CurrencyRate?
    private let server: RPCServer
    private let fullFormatter = EtherNumberFormatter.full

    private var gasViewModel: GasViewModel {
        return GasViewModel(fee: totalFee, symbol: server.symbol, currencyRate: currencyRate, formatter: fullFormatter)
    }

    private var totalFee: BigInt {
        return transaction.gasPrice * transaction.gasLimit
    }

    private var gasLimit: BigInt {
        return transaction.gasLimit
    }

    init(
        transaction: PreviewTransaction,
        server: RPCServer,
        currentBalance: BalanceProtocol?,
        currencyRate: CurrencyRate?
    ) {
        self.transaction = transaction
        self.currentBalance = currentBalance
        self.server = server
        self.currencyRate = currencyRate
    }

    var amount: String {
        return fullFormatter.string(from: transaction.value)
    }

    var paymentFromTitle: String {
        return R.string.localizable.confirmPaymentFromLabelTitle()
    }

    var paymentToTitle: String {
        return R.string.localizable.confirmPaymentToLabelTitle()
    }
    var paymentToText: String {
        return transaction.address?.description ?? "--"
    }

    var gasPriceTitle: String {
        return R.string.localizable.confirmPaymentGasPriceLabelTitle()
    }

    var gasPriceText: String {
        let unit = UnitConfiguration.gasPriceUnit
        let amount = fullFormatter.string(from: transaction.gasPrice, units: UnitConfiguration.gasPriceUnit)
        return  String(
            format: "%@ %@",
            amount,
            unit.name
        )
    }

    var feeTitle: String {
        return R.string.localizable.confirmPaymentGasFeeLabelTitle()
    }

    var feeText: String {
        let feeAndSymbol = gasViewModel.feeText
        let warningFee = BigInt(EthereumUnit.ether.rawValue) / BigInt(20)
        guard totalFee <= warningFee else {
            return R.string.localizable.confirmPaymentHighFeeWarning(feeAndSymbol)
        }
        return feeAndSymbol
    }

    var gasLimitTitle: String {
        return R.string.localizable.confirmPaymentGasLimitLabelTitle()
    }

    var gasLimitText: String {
        return gasLimit.description
    }

    var amountTextColor: UIColor {
        return Colors.red
    }

    var dataTitle: String {
        return R.string.localizable.confirmPaymentDataLabelTitle()
    }

    var dataText: String {
        return transaction.data.description
    }

    var nonceTitle: String {
        return R.string.localizable.confirmPaymentNonceLabelTitle()
    }

    var nonceText: String {
        transaction.nonce.description
    }

    var isNonceSet: Bool {
        transaction.nonce > -1
    }

    var amountAttributedString: NSAttributedString {
        switch transaction.transferType {
        case .ERC20Token(let token, _, _):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .nativeCryptocurrency, .dapp:
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value)
            )
        case .ERC875Token(let token):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC875TokenOrder(let token):
            return amountAttributedText(
                    string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC721Token(let token):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC721ForTicketToken(let token):
            return amountAttributedText(
                    string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        }
    }
    
    func canPay(includeTxCost: Bool, maxFund: BigInt) -> Bool {
        switch transaction.transferType {
        case .ERC20Token:
            return transaction.value <= maxFund
        case .nativeCryptocurrency, .dapp:
            return canPayWithTxFee(includeTxCost: includeTxCost, maxFund: maxFund)
        case .ERC875Token:
            return canPayWithTxFee(includeTxCost: includeTxCost, maxFund: maxFund)
        case .ERC875TokenOrder:
            return canPayWithTxFee(includeTxCost: includeTxCost, maxFund: maxFund)
        case .ERC721Token:
            return transaction.value <= maxFund
        case .ERC721ForTicketToken:
            return transaction.value <= maxFund
        }
    }
    
    private func canPayWithTxFee(includeTxCost: Bool, maxFund: BigInt) -> Bool {
        if includeTxCost {
            if totalFee > transaction.value {
                return totalFee - transaction.value <= maxFund
            } else {
                return transaction.value <= maxFund
            }
        } else {
            return transaction.value + totalFee <= maxFund
        }
    }
    
    var amountPlusFee: BigInt {
        let modifiedTr = transaction.value + totalFee
        switch transaction.transferType {
        case .ERC20Token:
            return transaction.value
        case .nativeCryptocurrency, .dapp:
            return modifiedTr
        case .ERC875Token:
            return modifiedTr
        case .ERC875TokenOrder:
            return modifiedTr
        case .ERC721Token:
            return transaction.value
        case .ERC721ForTicketToken:
            return transaction.value
        }
    }
    
    var amountMinusFee: BigInt {
        let modifiedTr = totalFee > transaction.value ? 0 : transaction.value - totalFee
        switch transaction.transferType {
        case .ERC20Token:
            return transaction.value
        case .nativeCryptocurrency, .dapp:
            return modifiedTr
        case .ERC875Token:
            return modifiedTr
        case .ERC875TokenOrder:
            return modifiedTr
        case .ERC721Token:
            return transaction.value
        case .ERC721ForTicketToken:
            return transaction.value
        }
    }
    
    var amountAttributedStringWithFee: NSAttributedString {
        let modifiedTr = totalFee > transaction.value ? 0 : transaction.value - totalFee
         switch transaction.transferType {
              case .ERC20Token(let token, _, _):
                  return amountAttributedText(
                    string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
                  )
              case .nativeCryptocurrency, .dapp:
                  return amountAttributedText(
                      string: fullFormatter.string(from: modifiedTr)
                  )
              case .ERC875Token(let token):
                  return amountAttributedText(
                      string: fullFormatter.string(from: modifiedTr, decimals: token.decimals)
                  )
              case .ERC875TokenOrder(let token):
                  return amountAttributedText(
                          string: fullFormatter.string(from: modifiedTr, decimals: token.decimals)
                  )
              case .ERC721Token(let token):
                  return amountAttributedText(
                    string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
                  )
              case .ERC721ForTicketToken(let token):
                  return amountAttributedText(
                    string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
                  )
              }
    }

    private func amountAttributedText(string: String) -> NSAttributedString {
        var currency:NSAttributedString
        let amount = NSAttributedString(
            string: amountWithSign(for: string),
            attributes: [
                .font: Fonts.regular(size: 28) as Any,
                .foregroundColor: amountTextColor,
            ]
        )
        if transaction.transferType.symbol == "ETH" {
            currency = NSAttributedString(
                string: " ILG",
                attributes: [
                    .font: Fonts.regular(size: 20) as Any,
                ]
            )
        } else {
            currency = NSAttributedString(
                       string: " \(transaction.transferType.symbol)",
                       attributes: [
                           .font: Fonts.regular(size: 20) as Any,
                       ]
                   )

        }
        return amount + currency
    }

    private func amountWithSign(for amount: String) -> String {
        guard amount != "0" else { return amount }
        return "-\(amount)"
    }
}
