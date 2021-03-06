// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AccountViewCell: UITableViewCell {
    private let addressLabel = UILabel()
    private let balanceLabel = UILabel()
    private let blockieImageView = BlockieImageView()

    var viewModel: AccountViewModel?
    var account: Wallet?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        isUserInteractionEnabled = true
        addressLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            balanceLabel,
            addressLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        let stackView = [blockieImageView, leftStackView].asStackView(spacing: 20, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addressLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        balanceLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stackView.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            blockieImageView.heightAnchor.constraint(equalToConstant: 40),
            blockieImageView.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 20, left: 20, bottom: 20, right: 0)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: AccountViewModel) {
        self.viewModel = viewModel

        backgroundColor = viewModel.backgroundColor

        balanceLabel.font = viewModel.balanceFont
        balanceLabel.text = viewModel.balance

        addressLabel.font = viewModel.addressFont
        addressLabel.textColor = viewModel.addressTextColor
        addressLabel.text = viewModel.addresses

        accessoryType = viewModel.accessoryType

        blockieImageView.subscribable = viewModel.icon
    }
}

