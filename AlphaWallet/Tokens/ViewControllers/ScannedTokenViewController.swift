//
//  ScannedTokenViewController.swift
//  AlphaWallet
//
//  Created by Famil Samadli on 11/4/20.
//

import UIKit
import StatefulViewController
//import WalletConnect
import PromiseKit
import WalletCore
import UserNotifications
import BigInt
import web3swift

protocol ScannedTokenViewControllerDelegate: class {
    func controller(_ controller: ScannedTokenViewController, didSelectToken token: TokenObject)
    func controller(_ controller: ScannedTokenViewController, didCancelSelected sender: UIBarButtonItem)
}

class ScannedTokenViewController: UIViewController, UITextFieldDelegate {
    /*
    var interactor: WCInteractor?
      let clientMeta = WCPeerMeta(name: "WalletConnect SDK", url: "https://github.com/TrustWallet/wallet-connect-swift")

      let privateKey = PrivateKey(data: Data(hexString: "3f74bb79cf1313d3a99e58ab087f4d69ff5ae502e556c5fa7599d306e1a9fa02")!)!
    */

    var defaultAddress: String = ""
    var defaultChainId: Int = 1768711028
    var recoverSession: Bool = false
    var notificationGranted: Bool = false
    let server:RPCServer
    let keystore:Keystore
    
    private var backgroundTaskId: UIBackgroundTaskIdentifier?
    private weak var backgroundTimer: Timer?
    
    weak var delegate: ScannedTokenViewControllerDelegate?
    private var urlTextField =  UITextField()
    private var addressTextField =  UITextField()
    private var codeTextField =  UITextField()
    private var connectButton = UIButton()
    private var approveButton = UIButton()
    
    private var walletConnectURL:String = ""
    
    init(walletConnectURL:String, server:RPCServer, keystore:Keystore) {
        self.walletConnectURL = walletConnectURL
        self.server = server
        self.keystore = keystore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        //main view
        view = UIView()
        view.backgroundColor = .white
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
       // defaultAddress = CoinType.ethereum.deriveAddress(privateKey: privateKey)

        navigationController?.applyTintAdjustment()
        navigationController?.navigationBar.prefersLargeTitles = false
        hidesBottomBarWhenPushed = true
        navigationItem.title = "Scanned QR Data"
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.black]
        navigationItem.rightBarButtonItem = UIBarButtonItem.closeBarButton(self, selector: #selector(dismiss))
        
        //text fields
        addressTextField.text = defaultAddress
        urlTextField(width: Int(view.bounds.size.width-40))
        addressTextField(width: Int(view.bounds.size.width-40))
        codeTextField(width: Int(view.bounds.size.width-40))
        connectButtonRender(midX: Int(view.frame.midX/1.4))
        approveButtonRender(midX: Int(view.frame.midX/1.4))
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (granted, error) in
                   print("<== notification permission: \(granted)")
                   if let error = error {
                       print(error)
                   }
                   self.notificationGranted = granted
               }
    }
    
    @objc private func dismiss(_ sender: UIBarButtonItem) {
        delegate?.controller(self, didCancelSelected: sender)
    }
    
    func labelRender(labelText: String, yCoordinate: Int) {
        let label = UILabel(frame: CGRect(x: 20, y: yCoordinate, width: 230, height: 21))
        label.text = labelText
        label.textColor = .black
        label.font = UIFont.boldSystemFont(ofSize: 15)
        
        view.addSubview(label)
    }
    
    func urlTextField(width: Int) {
        
        labelRender(labelText: "Url", yCoordinate: 170)
        urlTextField =  UITextField(frame: CGRect(x: 20, y: 195, width: width, height: 40))
        urlTextField.text = self.walletConnectURL
        urlTextField.placeholder = "Enter url here"
        urlTextField.font = UIFont.systemFont(ofSize: 15)
        urlTextField.borderStyle = UITextField.BorderStyle.roundedRect
        urlTextField.autocorrectionType = UITextAutocorrectionType.no
        urlTextField.keyboardType = UIKeyboardType.default
        urlTextField.returnKeyType = UIReturnKeyType.done
        urlTextField.clearButtonMode = UITextField.ViewMode.whileEditing
        urlTextField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        urlTextField.delegate = self
        
        view.addSubview(urlTextField)
    }
    /*
    func connect(session: WCSession) {
           //print("==> session", session)
          // let interactor = WCInteractor(session: session, meta: clientMeta, uuid: UIDevice.current.identifierForVendor ?? UUID())

           configure(interactor: interactor)

           interactor.connect().done { [weak self] connected in
               self?.connectionStatusUpdated(connected)
           }.catch { [weak self] error in
               self?.present(error: error)
           }

           self.interactor = interactor
       }

       func configure(interactor: WCInteractor) {
           let accounts = [defaultAddress]
           let chainId = defaultChainId

           interactor.onError = { [weak self] error in
               self?.present(error: error)
           }

           interactor.onSessionRequest = { [weak self] (id, peerParam) in
               let peer = peerParam.peerMeta
               let message = [peer.description, peer.url].joined(separator: "\n")
               
                          let alert = UIAlertController(title: peer.name, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { _ in
                self?.interactor?.rejectSession().cauterize()
            }))
            alert.addAction(UIAlertAction(title: "Approve", style: .default, handler: { _ in
                self?.interactor?.approveSession(accounts: accounts, chainId: chainId).cauterize()
            }))

            self!.present(alert, animated: true, completion: nil)

           }

           interactor.onDisconnect = { [weak self] (error) in
               if let error = error {
                   print(error)
               }
               self?.connectionStatusUpdated(false)
           }

           interactor.eth.onSign = { [weak self] (id, payload) in
               let alert = UIAlertController(title: payload.method, message: payload.message, preferredStyle: .alert)
               alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
                   self?.interactor?.rejectRequest(id: id, message: "User canceled").cauterize()
               }))
               alert.addAction(UIAlertAction(title: "Sign", style: .default, handler: { _ in
                   self?.signEth(id: id, payload: payload)
               }))
               self!.present(alert, animated: true, completion: nil)
           }

           interactor.eth.onTransaction = { [weak self] (id, event, transaction) in
            let data = try! JSONEncoder().encode(transaction)
               let message = String(data: data, encoding: .utf8)
               let alert = UIAlertController(title: event.rawValue, message: message, preferredStyle: .alert)
            
           var jsonDict = (try? JSONSerialization.jsonObject(with: Data(data))) as? [String: Any]
        
            
            let web3 = Web3Options.fromJSON(jsonDict!)
           
            let address = EthereumAddress(jsonDict!["to"] as! String)
            
            let tr = EthereumTransaction.init(to: address!, data: data, options: web3!)
            
            let to = AlphaWallet.Address.init(string:jsonDict!["to"] as! String)
            
            let from = AlphaWallet.Address.init(string:jsonDict!["from"] as! String)
            
            var raw = [String]()
            
            jsonDict!.values.forEach{
                // $0 is your dict value..
                print($0)
                raw.append($0 as! String)
            }
            
          
          
               
               alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { _ in
                   self?.interactor?.rejectRequest(id: id, message: "I don't have ethers").cauterize()
               }))
            alert.addAction(UIAlertAction(title: "Approve", style: .destructive, handler: { _ in
                self!.signEth(id: id, payload: WCEthereumSignPayload.sign(data: data, raw: raw))
                        }))
               self!.present(alert, animated: true, completion: nil)
           }
        
            

           interactor.bnb.onSign = { [weak self] (id, order) in
               let message = order.encodedString
               let alert = UIAlertController(title: "bnb_sign", message: message, preferredStyle: .alert)
               alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { [weak self] _ in
                   self?.interactor?.rejectRequest(id: id, message: "User canceled").cauterize()
               }))
               alert.addAction(UIAlertAction(title: "Sign", style: .default, handler: { [weak self] _ in
                   self?.signBnbOrder(id: id, order: order)
               }))
               self!.present(alert, animated: true, completion: nil)
           }
       }

       func approve(accounts: [String], chainId: Int) {
           interactor?.approveSession(accounts: accounts, chainId: chainId).done {
               print("<== approveSession done")
           }.catch { [weak self] error in
               self?.present(error: error)
           }
       }
    
    
    func signEthTr(tr: EthereumTransaction, to: AlphaWallet.Address, from: AlphaWallet.Address, id:Int64) {
       
        
        let unsignedTr = UnsignedTransaction.init(value: BigInt(tr.value), account: EthereumAccount.init(address: from), to: to, nonce: Int(tr.nonce), data: tr.data, gasPrice: BigInt(tr.gasPrice), gasLimit: BigInt(tr.gasLimit), server: server)
        
        let signedTr = self.keystore.signTransaction(unsignedTr)
        switch signedTr {
              case .success(let data):
                self.interactor?.approveRequest(id: id, result: data.hexString).cauterize()
              case .failure(let error):
                  print("error")
              }
        
        
         }

       func signEth(id: Int64, payload: WCEthereumSignPayload) {
           let data: Data = {
               switch payload {
               case .sign(let data, _):
                   return data
               case .personalSign(let data, _):
                   let prefix = "\u{19}Ethereum Signed Message:\n\(data)".data(using: .utf8)!
                   return prefix + data
               case .signTypeData(_, let data, _):
                   // FIXME
                   return data
               }
           }()

           var result = privateKey.sign(digest: Hash.keccak256(data: data), curve: .secp256k1)!
           result[64] += 27
           self.interactor?.approveRequest(id: id, result: "0x" + result.hexString).cauterize()
       }
    
    
    func signEthData(id: Int64, data:Data) {
             

              var result = privateKey.sign(digest: Hash.keccak256(data: data), curve: .secp256k1)!
              result[64] += 27
              self.interactor?.approveRequest(id: id, result: "0x" + result.hexString).cauterize()
          }

       func signBnbOrder(id: Int64, order: WCBinanceOrder) {
           let data = order.encoded
           print("==> signbnbOrder", String(data: data, encoding: .utf8)!)
           let signature = privateKey.sign(digest: Hash.sha256(data: data), curve: .secp256k1)!
           let signed = WCBinanceOrderSignature(
               signature: signature.dropLast().hexString,
               publicKey: privateKey.getPublicKeySecp256k1(compressed: false).data.hexString
           )
           interactor?.approveBnbOrder(id: id, signed: signed).done({ confirm in
               print("<== approveBnbOrder", confirm)
           }).catch { [weak self] error in
               self?.present(error: error)
           }
       }
*/
       func connectionStatusUpdated(_ connected: Bool) {
           self.approveButton.isEnabled = connected
           self.connectButton.setTitle(!connected ? "Connect" : "Kill Session", for: .normal)
       }

       func present(error: Error) {
           let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
           alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
       }
    
    func addressTextField(width: Int) {
        
        labelRender(labelText: "Address", yCoordinate: 250)
        addressTextField =  UITextField(frame: CGRect(x: 20, y: 275, width: width, height: 40))
        
        addressTextField.placeholder = "Enter address here"
        addressTextField.text = defaultAddress
        addressTextField.font = UIFont.systemFont(ofSize: 15)
        addressTextField.borderStyle = UITextField.BorderStyle.roundedRect
        addressTextField.autocorrectionType = UITextAutocorrectionType.no
        addressTextField.keyboardType = UIKeyboardType.default
        addressTextField.returnKeyType = UIReturnKeyType.done
        addressTextField.clearButtonMode = UITextField.ViewMode.whileEditing
        addressTextField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        addressTextField.delegate = self
        view.addSubview(addressTextField)
    }
    
    func codeTextField(width: Int) {
        labelRender(labelText: "Code", yCoordinate: 330)
        codeTextField =  UITextField(frame: CGRect(x: 20, y: 355, width: width, height: 40))
        
        codeTextField.placeholder = "Enter code here"
        codeTextField.font = UIFont.systemFont(ofSize: 15)
        codeTextField.borderStyle = UITextField.BorderStyle.roundedRect
        codeTextField.autocorrectionType = UITextAutocorrectionType.no
        codeTextField.keyboardType = UIKeyboardType.default
        codeTextField.returnKeyType = UIReturnKeyType.done
        codeTextField.clearButtonMode = UITextField.ViewMode.whileEditing
        codeTextField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        codeTextField.delegate = self
        view.addSubview(codeTextField)
    }
    
    func connectButtonRender(midX: Int) {
        connectButton = UIButton(frame: CGRect(x: midX, y: 400, width: 100, height: 50))
        connectButton.setTitle("Connect", for: .normal)
        connectButton.setTitleColor(UIColor.blue, for: .normal)
        connectButton.addTarget(self, action: #selector(connectButtonPressed), for: .touchUpInside)
        view.addSubview(connectButton)
    }
    
    func approveButtonRender(midX: Int) {
        approveButton = UIButton(frame: CGRect(x: midX, y: 430, width: 100, height: 50))
        approveButton.setTitle("Approve", for: .normal)
        approveButton.setTitleColor(UIColor.lightGray, for: .normal)
        approveButton.addTarget(self, action: #selector(approveButtonPressed), for: .touchUpInside)
        view.addSubview(approveButton)
    }
    
    
    
    @objc func connectButtonPressed() {
       /*
        guard let string = urlTextField.text, let session = WCSession.from(string: string) else {
                  print("invalid uri: \(String(describing: urlTextField.text))")
                  return
              }
              if let i = interactor, i.state == .connected {
                  i.killSession().done {  [weak self] in
                      self?.approveButton.isEnabled = false
                      self?.connectButton.setTitle("Connect", for: .normal)
                  }.cauterize()
              } else {
                  connect(session: session)
              }*/
    }
    
    @objc func approveButtonPressed() {
        //ToDo
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {   //delegate method
       textField.resignFirstResponder()
       return true
    }
}




