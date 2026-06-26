//
//  CarouselPaywallPage.swift
//  nest-note
//

import SwiftUI

extension PaywallFeatureCarouselCard: Identifiable {}

struct CarouselPaywallPlan: Identifiable, Equatable {
    let id: String
    let title: String
    let price: String
    let secondaryPrice: String?
    let billingDetail: String
}

enum CarouselPaywallStage {
    case features
    case checkout
}

@MainActor
final class CarouselPaywallViewModel: ObservableObject {
    @Published var stage: CarouselPaywallStage = .features
    @Published var headline = "Upgrade to Premium"
    @Published var trialInfo = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var plans: [CarouselPaywallPlan] = []
    @Published var selectedPlanID: String?
    @Published var appliedReferralCode: String?
    @Published var appliedReferralCodeType: ReferralCodeType?
    @Published var showReferralSheet = false
    @Published var referralCodeInput = ""
    @Published var referralCodeError: String?

    var onPrimaryAction: () -> Void = {}
    var onRestore: () -> Void = {}
    var onTerms: () -> Void = {}
    var onPrivacy: () -> Void = {}
    var onApplyReferralCode: (String) -> Void = { _ in }
    var onSelectPlan: (String) -> Void = { _ in }

    var primaryButtonTitle: String {
        stage == .features ? "Continue" : "Upgrade Now"
    }

    var isPrimaryButtonEnabled: Bool {
        guard !isLoading else { return false }
        if stage == .checkout {
            return selectedPlanID != nil
        }
        return true
    }
}

struct CarouselPaywallPage: View {

    private static let cardWHRatio: CGFloat = 1.77
    private static let featuresCardToScreenRatio: CGFloat = 0.38
    private static let checkoutCardToScreenRatio: CGFloat = 0.28
    private static let carouselSpacing: CGFloat = 30

    @ObservedObject var viewModel: CarouselPaywallViewModel

    @State private var activeCard: PaywallFeatureCarouselCard? = paywallFeatureCarouselCards.first
    @State private var captionTitle = paywallFeatureCarouselCards.first?.feature.displayName ?? ""
    @State private var captionDescription = paywallFeatureCarouselCards.first?.feature.description ?? ""
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var currentScrollOffset: CGFloat = 0
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .default).autoconnect()
    @State private var initialAnimation = false
    @State private var titleProgress: CGFloat = 0
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var isUserDragging = false

    var body: some View {
        ZStack {
            AmbientBackground()
                .animation(.easeInOut(duration: 1), value: activeCard)

            VStack(spacing: 0) {
                paywallHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 28)
                    .blurOpacityEffect(initialAnimation)

                InfiniteScrollView(spacing: Self.carouselSpacing) {
                    ForEach(paywallFeatureCarouselCards) { card in
                        FeatureCarouselCardView(
                            card,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                    }
                }
                .frame(height: cardHeight + 12)
                .animation(.smooth(duration: 0.55), value: viewModel.stage)
                .scrollIndicators(.hidden)
                .scrollPosition($scrollPosition)
                .scrollClipDisabled()
                .onScrollPhaseChange { _, newPhase in
                    scrollPhase = newPhase
                    isUserDragging = newPhase == .interacting || newPhase == .decelerating
                }
                .onScrollGeometryChange(for: CGFloat.self) {
                    $0.contentOffset.x + $0.contentInsets.leading
                } action: { _, newValue in
                    currentScrollOffset = newValue
                    updateActiveCard()
                }
                .visualEffect { [initialAnimation] content, proxy in
                    content
                        .offset(y: initialAnimation ? 0 : -(proxy.size.height + 200))
                }

                activeFeatureCaption
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .animation(.smooth(duration: 0.55), value: viewModel.stage)

                Spacer(minLength: 8)

                bottomPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .blurOpacityEffect(initialAnimation)
            }
            .safeAreaPadding(.top, 4)
            .safeAreaPadding(.bottom, 8)

            if viewModel.isLoading {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .sheet(isPresented: $viewModel.showReferralSheet) {
            ReferralCodeEntrySheet(viewModel: viewModel)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .onReceive(timer) { _ in
            guard !isUserDragging else { return }
            currentScrollOffset += 0.35
            scrollPosition.scrollTo(x: currentScrollOffset)
        }
        .task {
            try? await Task.sleep(for: .seconds(0.2))

            withAnimation(.smooth(duration: 0.75, extraBounce: 0)) {
                initialAnimation = true
            }

            withAnimation(.smooth(duration: 2.0, extraBounce: 0).delay(0.2)) {
                titleProgress = 1
            }
        }
    }

    private var cardToScreenRatio: CGFloat {
        viewModel.stage == .features ? Self.featuresCardToScreenRatio : Self.checkoutCardToScreenRatio
    }

    private var cardHeight: CGFloat {
        UIScreen.main.bounds.height * cardToScreenRatio
    }

    private var cardWidth: CGFloat {
        cardHeight / Self.cardWHRatio
    }

    private var paywallHeader: some View {
        VStack(spacing: 12) {
            Image(AppIcon.dark.previewImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            Text(viewModel.headline)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .textRenderer(TitleTextRenderer(progress: titleProgress))
        }
    }

    private var activeFeatureCaption: some View {
        VStack(spacing: 6) {
            Text(captionTitle)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .contentTransition(.interpolate)

            Text(captionDescription)
                .font(.subheadline)
                .foregroundStyle(.white.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54, alignment: .top)
                .contentTransition(.interpolate)
        }
        .frame(height: 82)
    }

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            if viewModel.stage == .checkout {
                checkoutContent
            }

            if viewModel.stage == .features {
                featuresStageContent
            }

            Button {
                viewModel.onPrimaryAction()
            } label: {
                Text(viewModel.primaryButtonTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: .capsule)
            }
            .disabled(!viewModel.isPrimaryButtonEnabled)
            .opacity(viewModel.isPrimaryButtonEnabled ? 1 : 0.6)

            HStack(spacing: 16) {
                footerButton("Terms") { viewModel.onTerms() }
                footerButton("Privacy") { viewModel.onPrivacy() }
                footerButton("Restore") { viewModel.onRestore() }
            }
            .padding(.top, 2)
        }
        .animation(.smooth(duration: 0.4), value: viewModel.stage)
    }

    private var featuresStageContent: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.referralCodeError = nil
                viewModel.showReferralSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ticket.fill")
                    Text("Have a referral code?")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                }
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)

            if let code = viewModel.appliedReferralCode {
                Label("Code applied: \(code)", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private var checkoutContent: some View {
        if let code = viewModel.appliedReferralCode {
            Label("Referral code: \(code)", systemImage: "ticket.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.secondary)
                .frame(maxWidth: .infinity)
        }

        if !viewModel.plans.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                ForEach(viewModel.plans) { plan in
                    PlanOptionView(
                        plan: plan,
                        isSelected: viewModel.selectedPlanID == plan.id
                    ) {
                        viewModel.onSelectPlan(plan.id)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }

        if !viewModel.trialInfo.isEmpty {
            Text(viewModel.trialInfo)
                .font(.caption)
                .foregroundStyle(.white.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.secondary)
        }
    }

    private func updateActiveCard() {
        guard cardWidth > 0 else { return }

        let cardStep = cardWidth + Self.carouselSpacing
        let rawIndex = Int((currentScrollOffset / cardStep).rounded())
        let activeIndex = ((rawIndex % paywallFeatureCarouselCards.count) + paywallFeatureCarouselCards.count) % paywallFeatureCarouselCards.count
        let newCard = paywallFeatureCarouselCards[activeIndex]

        guard newCard.id != activeCard?.id else { return }

        withAnimation(.smooth(duration: 0.45)) {
            activeCard = newCard
            captionTitle = newCard.feature.displayName
            captionDescription = newCard.feature.description
        }
    }

    @ViewBuilder
    private func AmbientBackground() -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                ForEach(paywallFeatureCarouselCards) { card in
                    Image(card.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .frame(width: size.width, height: size.height)
                        .opacity(activeCard?.id == card.id ? 1 : 0)
                }

                Rectangle()
                    .fill(.black.opacity(0.55))
                    .ignoresSafeArea()
            }
            .compositingGroup()
            .blur(radius: 90, opaque: true)
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func FeatureCarouselCardView(
        _ card: PaywallFeatureCarouselCard,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .bottomLeading) {
                Image(card.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipShape(.rect(cornerRadius: 20))

                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(.rect(cornerRadius: 20))

                HStack(spacing: 8) {
                    Image(systemName: card.feature.iconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.2), in: .circle)

                    Text(card.feature.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(12)
            }
            .shadow(color: .black.opacity(0.4), radius: 10, x: 1, y: 0)
        }
        .frame(width: cardWidth, height: cardHeight)
        .scrollTransition(.interactive.threshold(.centered), axis: .horizontal) { content, phase in
            content
                .offset(y: phase == .identity ? -10 : 0)
                .rotationEffect(.degrees(phase.value * 5), anchor: .bottom)
        }
    }
}

private struct ReferralCodeEntrySheet: View {
    @ObservedObject var viewModel: CarouselPaywallViewModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Enter Referral Code")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Support a creator and unlock partner pricing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Referral Code", text: $viewModel.referralCodeInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($isFieldFocused)

            if let error = viewModel.referralCodeError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                viewModel.onApplyReferralCode(viewModel.referralCodeInput)
            } label: {
                Text("Apply Code")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black, in: .capsule)
            }
            .disabled(viewModel.referralCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding(24)
        .onAppear {
            isFieldFocused = true
        }
    }
}

private struct PlanOptionView: View {
    private static let cardHeight: CGFloat = 112

    let plan: CarouselPaywallPlan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(Font(UIFont.h4))
                            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.95))

                        Text(plan.price)
                            .font(Font(UIFont.h4))
                            .foregroundStyle(.white)

                        if let secondaryPrice = plan.secondaryPrice {
                            Text(secondaryPrice)
                                .font(Font(UIFont.bodyS))
                                .foregroundStyle(.white.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.35))
                }
                .padding(.top, 12)
                .padding(.horizontal, 12)

                Text(plan.billingDetail)
                    .font(Font(UIFont.bodyS))
                    .foregroundStyle(.white.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, minHeight: Self.cardHeight, maxHeight: Self.cardHeight)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.1))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.25), lineWidth: isSelected ? 2 : 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Stage 1") {
    let viewModel = CarouselPaywallViewModel()
    return CarouselPaywallPage(viewModel: viewModel)
}

#Preview("Stage 2") {
    let viewModel = CarouselPaywallViewModel()
    viewModel.headline = "Upgrade to Premium"
    viewModel.stage = .checkout
    viewModel.appliedReferralCode = "NEST20"
    viewModel.trialInfo = "3-day free trial, then $29.99/yr. Cancel anytime."
    viewModel.plans = [
        .init(id: "monthly", title: "Monthly", price: "$4.99/mo", secondaryPrice: nil, billingDetail: "Billed at $4.99/mo."),
        .init(id: "annual", title: "Annual", price: "$29.99/yr", secondaryPrice: "$2.50/mo", billingDetail: "Billed at $29.99/yr after free trial."),
    ]
    viewModel.selectedPlanID = "annual"
    return CarouselPaywallPage(viewModel: viewModel)
}
