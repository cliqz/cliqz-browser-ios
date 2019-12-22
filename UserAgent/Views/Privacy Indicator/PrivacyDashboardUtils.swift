import Shared

enum PrivacyDashboardUtils {
    class HStack: UIStackView {
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        init(_ callback: () -> (UIView, UILabel)) {
            super.init(frame: CGRect.zero)
            let (dot, label) = callback()
            self.columns(dot: dot, label: label)
        }
        init(_ callback: () -> (UIView, UILabel, UILabel)) {
            super.init(frame: CGRect.zero)
            let (dot, label, number) = callback()
            self.columns(dot: dot, label: label, number: number)
        }
        private func columns(dot: UIView, label: UILabel, number: UILabel) {
            self.spacing = 5
            self.alignment = .top
            self.distribution = .fillProportionally
            [dot, label, number].forEach { self.addArrangedSubview($0)}
            number.alpha = 0.7
            number.textAlignment = .right

            label.snp.makeConstraints { make in
                make.width.lessThanOrEqualTo(100)
            }
            number.snp.makeConstraints { make in
                // space for keeping three digits [18, 25]
                make.width.greaterThanOrEqualTo(18)
                make.width.lessThanOrEqualTo(25)
            }
        }
        private func columns(dot: UIView, label: UILabel) {
            self.spacing = 5
            self.alignment = .top
            [dot, label].forEach { self.addArrangedSubview($0)}
        }
    }

    class Label: UILabel {
        enum LabelType { case title, stat, domain, counter }
        init(withType type: LabelType, _ text: String) {
            super.init(frame: CGRect.zero)
            self.text = text
            switch type {
            case .title: self.title()
            case .stat: self.stat()
            case .domain: self.domain()
            case .counter: self.counter()
            }
        }
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        private func title() {
            self.font = UIFont.preferredFont(forTextStyle: .title1)
            self.adjustsFontForContentSizeCategory = true
            self.numberOfLines = 3
            self.lineBreakMode = .byWordWrapping
        }
        private func stat() {
            self.textColor = Theme.textField.textAndTint
            self.numberOfLines = 0
            self.setContentCompressionResistancePriority(.required, for: .horizontal)
            self.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
        private func domain() {
            self.textColor = UIColor.DarkGreen
        }
        private func counter() {
            let pointSize = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
            self.font = UIFont.monospacedDigitSystemFont(ofSize: pointSize, weight: .medium)
        }
    }

    class Dot: UIView {
        init(withColor color: UIColor) {
            super.init(frame: CGRect.zero)
            let radius = 5
            let margin = 4
            self.snp.makeConstraints { make in
                make.width.equalTo(radius * 2)
                make.height.equalTo((radius * 2) + (margin * 2))
            }
            self.makeDot(withColor: color)
        }

        private func makeDot(withColor color: UIColor) {
            let radius = 5
            let view = UIView()
            view.backgroundColor = color
            view.layer.cornerRadius = CGFloat(radius)
            self.addSubview(view)

            view.snp.makeConstraints { make in
                make.width.equalTo(view.snp.height)
                make.height.equalTo(radius * 2)
                make.center.equalTo(self)
            }
        }
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    static func headerText(withStatus status: BlockerStatus?) -> String {
        if status == nil { return "" }
        switch status {
        case .Disabled: return ""
        case .NoBlockedURLs:
             return Strings.PrivacyDashboard.Title.NoTrackersSeen
        case .AdBlockWhitelisted:
             return Strings.PrivacyDashboard.Title.AdBlockWhitelisted
        case .AntiTrackingWhitelisted:
            return Strings.PrivacyDashboard.Title.AntiTrackingWhitelisted
        case .Whitelisted:
            return Strings.PrivacyDashboard.Title.Whitelisted
        case .Blocking:
            return Strings.PrivacyDashboard.Title.BlockingEnabled
        default: return ""
        }
    }
}
