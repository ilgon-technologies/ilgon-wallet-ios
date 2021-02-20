//
//  ScannedTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Famil Samadli on 11/4/20.
//

import UIKit

protocol ScannedTokenCoordinatorDelegate: class {
    func coordinator(_ coordinator: ScannedTokenCoordinator, didSelectToken token: TokenObject)
    func selectAssetDidCancel(in coordinator: ScannedTokenCoordinator)
}

class ScannedTokenCoordinator: Coordinator {

    private let parentsNavigationController: UINavigationController
    private let walletConnectURL:String
    private let server: RPCServer
    private let keystore: Keystore

    private lazy var viewController: ScannedTokenViewController = .init(walletConnectURL: self.walletConnectURL, server:self.server, keystore:self.keystore)

    lazy var navigationController = UINavigationController(rootViewController: viewController)
    var coordinators: [Coordinator] = []
    weak var delegate: ScannedTokenCoordinatorDelegate?
    
    
       
    //NOTE: `filter: WalletFilter` parameter allow us to to filter tokens we need
    init(navigationController: UINavigationController, walletConnectUrl:String, server:RPCServer, keystore:Keystore) {
        self.keystore = keystore
        self.server = server
        self.parentsNavigationController = navigationController
        self.walletConnectURL = walletConnectUrl
        self.navigationController.hidesBottomBarWhenPushed = true
        viewController.delegate = self
    }

    func start() {
        navigationController.makePresentationFullScreenForiOS13Migration()
        parentsNavigationController.present(navigationController, animated: true)
    }
}

extension TokensCoordinator: ScannedTokenCoordinatorDelegate {

    func coordinator(_ coordinator: ScannedTokenCoordinator, didSelectToken token: TokenObject) {
        removeCoordinator(coordinator)

        switch sendToAddressState {
        case .pending(let address):
            let paymentFlow = PaymentFlow.send(type: .init(token: token, recipient: .address(address), amount: nil))

            delegate?.didPress(for: paymentFlow, server: token.server, in: self)
        case .none:
            break
        }
    }

    func selectAssetDidCancel(in coordinator: ScannedTokenCoordinator) {
        removeCoordinator(coordinator)
    }
}


extension ScannedTokenCoordinator: ScannedTokenViewControllerDelegate {

    func controller(_ controller: ScannedTokenViewController, didSelectToken token: TokenObject) {
        //NOTE: for now we dismiss assets vc because then we will not able to close it, after payment flow.
        //first needs to update payment flow, make it push to navigation stack
        navigationController.dismiss(animated: true) {
            self.delegate?.coordinator(self, didSelectToken: token)
        }
    }

    func controller(_ controller: ScannedTokenViewController, didCancelSelected sender: UIBarButtonItem) {
        navigationController.dismiss(animated: true) {
            self.delegate?.selectAssetDidCancel(in: self)
        }
    }
}

