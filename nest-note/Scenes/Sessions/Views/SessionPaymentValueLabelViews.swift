import SwiftUI

// MARK: - Duration label (CSTemperatureSelectorRepresentable-style binding)

private final class SessionPaymentDurationLabelState: ObservableObject {
    @Published var minutes: Int
    init(minutes: Int) { self.minutes = minutes }
}

private struct SessionPaymentDurationLabelContent: View {
    @ObservedObject var state: SessionPaymentDurationLabelState

    private var hours: Int { state.minutes / 60 }
    private var remainder: Int { state.minutes % 60 }

    var body: some View {
        Group {
            if hours == 0 {
                durationPart(value: remainder, unit: "min")
            } else {
                HStack(spacing: 6) {
                    durationPart(value: hours, unit: "hr,")
                    durationPart(value: remainder, unit: "min")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.snappy, value: state.minutes)
    }

    @ViewBuilder
    private func durationPart(value: Int, unit: String) -> some View {
        HStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundStyle(Color.secondary)
        }
    }
}

final class SessionPaymentDurationLabelHost: UIView {
    private let state: SessionPaymentDurationLabelState
    private let hostingController: UIHostingController<SessionPaymentDurationLabelContent>

    init(minutes: Int) {
        state = SessionPaymentDurationLabelState(minutes: minutes)
        hostingController = UIHostingController(rootView: SessionPaymentDurationLabelContent(state: state))
        super.init(frame: .zero)
        setupHosting()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupHosting() {
        translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.sizingOptions = [.intrinsicContentSize]
        addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func setMinutes(_ minutes: Int, animated: Bool) {
        guard state.minutes != minutes else { return }
        if animated {
            withAnimation(.snappy) {
                state.minutes = minutes
            }
        } else {
            state.minutes = minutes
        }
    }
}

// MARK: - Hourly rate label

private final class SessionPaymentRateLabelState: ObservableObject {
    @Published var cents: Int
    init(cents: Int) { self.cents = cents }
}

private struct SessionPaymentRateLabelContent: View {
    @ObservedObject var state: SessionPaymentRateLabelState

    private var dollars: Int { state.cents / 100 }

    var body: some View {
        HStack(spacing: 0) {
            Text("$")
            Text("\(dollars)")
                .contentTransition(.numericText())
        }
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.snappy, value: state.cents)
    }
}

final class SessionPaymentRateLabelHost: UIView {
    private let state: SessionPaymentRateLabelState
    private let hostingController: UIHostingController<SessionPaymentRateLabelContent>

    init(cents: Int) {
        state = SessionPaymentRateLabelState(cents: cents)
        hostingController = UIHostingController(rootView: SessionPaymentRateLabelContent(state: state))
        super.init(frame: .zero)
        setupHosting()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupHosting() {
        translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.sizingOptions = [.intrinsicContentSize]
        addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func setCents(_ cents: Int, animated: Bool) {
        guard state.cents != cents else { return }
        if animated {
            withAnimation(.snappy) {
                state.cents = cents
            }
        } else {
            state.cents = cents
        }
    }
}
