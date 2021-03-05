// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit

protocol SettingsViewControllerDelegate: class, CanOpenURL {
    func settingsViewControllerAdvancedSettingsSelected(in controller: SettingsViewController)
    func settingsViewControllerChangeWalletSelected(in controller: SettingsViewController)
    func settingsViewControllerMyWalletAddressSelected(in controller: SettingsViewController)
    func settingsViewControllerBackupWalletSelected(in controller: SettingsViewController)
    func settingsViewControllerActiveNetworksSelected(in controller: SettingsViewController)
    func settingsViewControllerHelpSelected(in controller: SettingsViewController)
    func settingsViewControllerChangeLanguageSelected(in controller: SettingsViewController)
    func settingsViewControllerWalletConnectSelected(in controller: SettingsViewController)
}

class SettingsViewController: UIViewController {
    private let lock = Lock()
    private let config: Config
    private let keystore: Keystore
    private let account: Wallet
    private let analyticsCoordinator: AnalyticsCoordinator?
    private let promptBackupWalletViewHolder = UIView()
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.registerHeaderFooterView(SettingViewHeader.self)
        tableView.register(SettingTableViewCell.self)
        tableView.register(SwitchTableViewCell.self)
        tableView.separatorStyle = .singleLine

        return tableView
    }()
    private lazy var viewModel: SettingsViewModel = SettingsViewModel(account: account)

    weak var delegate: SettingsViewControllerDelegate?
    var promptBackupWalletView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let promptBackupWalletView = promptBackupWalletView {
                promptBackupWalletView.translatesAutoresizingMaskIntoConstraints = false
                promptBackupWalletViewHolder.addSubview(promptBackupWalletView)
                NSLayoutConstraint.activate([
                    promptBackupWalletView.leadingAnchor.constraint(equalTo: promptBackupWalletViewHolder.leadingAnchor, constant: 7),
                    promptBackupWalletView.trailingAnchor.constraint(equalTo: promptBackupWalletViewHolder.trailingAnchor, constant: -7),
                    promptBackupWalletView.topAnchor.constraint(equalTo: promptBackupWalletViewHolder.topAnchor, constant: 7),
                    promptBackupWalletView.bottomAnchor.constraint(equalTo: promptBackupWalletViewHolder.bottomAnchor, constant: 0),
                ])
                tabBarItem.badgeValue = "1"
                showPromptBackupWalletViewAsTableHeaderView()
            } else {
                hidePromptBackupWalletView()
                tabBarItem.badgeValue = nil
            }
        }
    }

    override func loadView() {
        view = tableView
    }

    init(config: Config, keystore: Keystore, account: Wallet, analyticsCoordinator: AnalyticsCoordinator?) {
        self.config = config
        self.keystore = keystore
        self.account = account
        self.analyticsCoordinator = analyticsCoordinator
        super.init(nibName: nil, bundle: nil)

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = R.string.localizable.aSettingsNavigationTitle()
        view.backgroundColor = GroupedTable.Color.background
        navigationItem.largeTitleDisplayMode = .automatic
        tableView.backgroundColor = GroupedTable.Color.background

        if promptBackupWalletView == nil {
            hidePromptBackupWalletView()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reflectCurrentWalletSecurityLevel()
    }

    private func showPromptBackupWalletViewAsTableHeaderView() {
        let size = promptBackupWalletViewHolder.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        promptBackupWalletViewHolder.bounds.size.height = size.height

        tableView.tableHeaderView = promptBackupWalletViewHolder
    }

    private func hidePromptBackupWalletView() {
        tableView.tableHeaderView = nil
    }

    private func reflectCurrentWalletSecurityLevel() {
        tableView.reloadData()
    }

    private func setPasscode(completion: ((Bool) -> Void)? = .none) {
        guard let navigationController = navigationController else { return }
        let viewModel = LockCreatePasscodeViewModel()
        let lock = LockCreatePasscodeCoordinator(navigationController: navigationController, model: viewModel)
        lock.start()
        lock.lockViewController.willFinishWithResult = { result in
            completion?(result)
            lock.stop()
        }
    }
    
    private func enableNotifications(completion: ((Bool) -> Void)? = .none) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let strongSelf = self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                DispatchQueue.main.async {
                    strongSelf.promptToEnableNotification(completion: completion)
                }
            case .authorized, .provisional:
                completion?(true)
            default:
                completion?(false)
            }
        }
    }
    
    private func promptToEnableNotification(completion: ((Bool) -> Void)? = .none) {
        guard let navigationController = navigationController else { return }
        navigationController.visibleViewController?.confirm(
               title: R.string.localizable.transactionsReceivedEtherNotificationPrompt(RPCServer.main.cryptoCurrencyName),
               message: nil,
               okTitle: R.string.localizable.oK(),
               okStyle: .default
        ) { result in
           switch result {
           case .success:
               //Give some time for the view controller to show up first. We don't have to be precise, so no need to complicate things with hooking up to the view controller's animation
               DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                   guard let strongSelf = self else { return }
                   strongSelf.requestForAuthorization()
               }
           case .failure:
               completion?(false)
           }
        }
    }

   private func requestForAuthorization(completion: ((Bool) -> Void)? = .none) {
       let notificationCenter = UNUserNotificationCenter.current()
       notificationCenter.requestAuthorization(options: [.badge, .alert, .sound]) { granted, error in
           if granted {
               completion?(true)
               DispatchQueue.main.async {
                   UIApplication.shared.registerForRemoteNotifications()
               }
           } else {
               completion?(false)
           }
       }
   }

    private func configureChangeWalletCellWithResolvedENS(_ row: SettingsWalletRow, cell: SettingTableViewCell) {
        cell.configure(viewModel: .init(
            titleText: row.title,
            subTitleText: self.viewModel.addressReplacedWithENSOrWalletName(),
            icon: row.icon)
        )

        firstly {
            GetWalletNameCoordinator(config: config).getName(forAddress: account.address)
        }.done { [weak self] name in
            guard let strongSelf = self else { return }
            //TODO check if still correct cell, since this is async
            let viewModel: SettingTableViewCellViewModel = .init(
                    titleText: row.title,
                    subTitleText: strongSelf.viewModel.addressReplacedWithENSOrWalletName(name),
                    icon: row.icon
            )
            cell.configure(viewModel: viewModel)
        }.cauterize()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension SettingsViewController: CanOpenURL {

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension SettingsViewController: SwitchTableViewCellDelegate {

    func cell(_ cell: SwitchTableViewCell, switchStateChanged isOn: Bool) {
        if cell.tag == PASSCODE_ROW_TAG {
            if isOn {
                setPasscode { result in
                    cell.isOn = result
                }
            } else {
                lock.deletePasscode()
            }
        } else if cell.tag == ALLOW_NOTI_ROW_TAG {
            if Config.allowNotifications == isOn { return }
            if isOn {
                enableNotifications {
                    [weak self] result in
                    self?.setAllowNotificationsOnMainThread(on: result, cell: cell)
                }
            } else {
                Config.setAllowNotifications(isOn)
            }
        }
    }
    
    private func setAllowNotificationsOnMainThread(on: Bool, cell: SwitchTableViewCell) {
        DispatchQueue.main.async {
            Config.setAllowNotifications(on)
            cell.setSwitchAnimated(on: on)
        }
    }
    
}

extension SettingsViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfSections(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.sections[indexPath.section] {
        case .system(let rows):
            let row = rows[indexPath.row]
            switch row {
            case .allowNotifications:
                let cell: SwitchTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(
                    titleText: row.title,
                    icon: row.icon,
                    value: Config.allowNotifications)
                )
                cell.delegate = self
                cell.tag = ALLOW_NOTI_ROW_TAG
                return cell
            case .passcode:
                let cell: SwitchTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(
                    titleText: viewModel.passcodeTitle,
                    icon: R.image.biometrics()!,
                    value: lock.isPasscodeSet)
                )
                cell.delegate = self
                cell.tag = PASSCODE_ROW_TAG
                return cell
            case .notifications, .selectActiveNetworks, .changeLanguage:
                let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(settingsSystemRow: row))

                return cell
            }
        case .help:
            let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(titleText: R.string.localizable.settingsSupportTitle(), icon: R.image.support()!))

            return cell
        case .wallet(let rows):
            let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            let row = rows[indexPath.row]
            switch row {
            case .changeWallet:
                configureChangeWalletCellWithResolvedENS(row, cell: cell)
            case .backup:
                cell.configure(viewModel: .init(settingsWalletRow: row))
                let walletSecurityLevel = PromptBackupCoordinator(keystore: self.keystore, wallet: self.account, config: .init(), analyticsCoordinator: analyticsCoordinator).securityLevel
                cell.accessoryView = walletSecurityLevel.flatMap { WalletSecurityLevelIndicator(level: $0) }
                cell.accessoryType = .disclosureIndicator
            case .showMyWallet:
                cell.configure(viewModel: .init(settingsWalletRow: row))
            case .walletConnect:
                cell.configure(viewModel: .init(settingsWalletRow: row))
            }

            return cell
        case .tokenStandard, .version:
            return UITableViewCell()
        }
    }
}

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: SettingViewHeader = tableView.dequeueReusableHeaderFooterView()
        let section = viewModel.sections[section]
        let viewModel = SettingViewHeaderViewModel(section: section)
        headerView.configure(viewModel: viewModel)

        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch viewModel.sections[indexPath.section] {
        case .wallet(let rows):
            switch rows[indexPath.row] {
            case .backup:
                delegate?.settingsViewControllerBackupWalletSelected(in: self)
            case .changeWallet:
                delegate?.settingsViewControllerChangeWalletSelected(in: self)
            case .showMyWallet:
                delegate?.settingsViewControllerMyWalletAddressSelected(in: self)
            case .walletConnect:
                delegate?.settingsViewControllerWalletConnectSelected(in: self)
            }
        case .system(let rows):
            switch rows[indexPath.row] {
            //case .advanced:
            //    delegate?.settingsViewControllerAdvancedSettingsSelected(in: self)
            case .allowNotifications:
                break
            case .notifications:
                break
            case .passcode:
                break
            case .selectActiveNetworks:
                delegate?.settingsViewControllerActiveNetworksSelected(in: self)
            case .changeLanguage:
                delegate?.settingsViewControllerChangeLanguageSelected(in: self)
            }
        case .help:
            delegate?.settingsViewControllerHelpSelected(in: self)
        case .tokenStandard:
            self.delegate?.didPressOpenWebPage(TokenScript.tokenScriptSite, in: self)
        case .version:
            break
        }
    }
}

private let ALLOW_NOTI_ROW_TAG = 10
private let PASSCODE_ROW_TAG = 11
