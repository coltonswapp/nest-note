//
//  IntroPage.swift
//  AppleInvites
//
//  Created by Luis Filipe Pedroso on 27/03/25.
//

import SwiftUI

struct IntroPage: View {
    
    static let cardWHRatio: CGFloat = 1.77
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var activeCard: Card? = cards.first
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var currentScrollOffset: CGFloat = 0
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .default).autoconnect()
    @State private var initialAnimation: Bool = false
    @State private var titleProgress: CGFloat = 0
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var showAuthButtons: Bool = false
    @State private var bottomContentHeight: CGFloat = 180

    var onGetStarted: () -> Void
    var onAppleSignIn: () -> Void
    var onLogin: () -> Void
    var onSignUp: () -> Void
    
    init(
        onGetStarted: @escaping () -> Void,
        onAppleSignIn: @escaping () -> Void = {},
        onLogin: @escaping () -> Void = {},
        onSignUp: @escaping () -> Void = {}
    ) {
        self.onGetStarted = onGetStarted
        self.onAppleSignIn = onAppleSignIn
        self.onLogin = onLogin
        self.onSignUp = onSignUp
    }
    
    var body: some View {
        ZStack {
            AmbientBackground()
                .animation(.easeInOut(duration: 1), value: activeCard)
            
            GeometryReader { geo in
                let carouselHeight = carouselHeight(in: geo.size.height)
                let carouselWidth = carouselHeight / Self.cardWHRatio

                VStack(spacing: contentSpacing) {
                    InfiniteScrollView {
                        ForEach(cards) { card in
                            CarouselCardView(card, cardWidth: carouselWidth, cardHeight: carouselHeight)
                        }
                    }
                    .frame(height: carouselHeight)
                    .padding(.top)
                    .scrollIndicators(.hidden)
                    .scrollPosition($scrollPosition)
                    .scrollClipDisabled()
                    .onScrollPhaseChange({ oldPhase, newPhase in
                        scrollPhase = newPhase
                    })
                    .onScrollGeometryChange(for: CGFloat.self) {
                        $0.contentOffset.x + $0.contentInsets.leading
                    } action: { oldValue, newValue in
                        currentScrollOffset = newValue

                        if scrollPhase != .decelerating || scrollPhase != .animating {
                            let rawIndex = Int((currentScrollOffset / carouselWidth).rounded())
                            let activeIndex = ((rawIndex % cards.count) + cards.count) % cards.count
                            activeCard = cards[activeIndex]
                        }
                    }
                    .visualEffect { [initialAnimation] content, proxy in
                            content
                            .offset(y: !initialAnimation ? -(proxy.size.height + 200) : 0)
                    }
                    .scaleEffect(showAuthButtons ? 0.75 : 1.0)
                    .animation(.smooth(duration: 0.6), value: showAuthButtons)
                    .padding(.top, showAuthButtons ? -40 : 20)

                    Spacer(minLength: 8)

                    VStack(spacing: contentSpacing) {
                        VStack(spacing: 4) {
                            Text("Welcome to")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.secondary)
                                .blurOpacityEffect(initialAnimation)

                            Text("NestNote")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                                .textRenderer(TitleTextRenderer(progress: titleProgress))
                                .padding(.bottom, 12)
                                .onTapGesture {
                                    withAnimation(.smooth(duration: 0.6)) {
                                        showAuthButtons = false
                                    }
                                }

                            Text("Keep your sitter informed, your family safe. \nEverything they need to know, right when they need it.")
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.secondary)
                                .blurOpacityEffect(initialAnimation)
                        }
                        .fixedSize(horizontal: false, vertical: true)

                        if !showAuthButtons {
                            Button {
                                withAnimation(.smooth(duration: 0.6)) {
                                    showAuthButtons = true
                                }
                                onGetStarted()
                            } label: {
                                Text("Get Started")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 25)
                                    .padding(.vertical, 12)
                                    .background(.white, in: .capsule)
                            }
                            .blurOpacityEffect(initialAnimation)
                            .opacity(showAuthButtons ? 0 : 1)
                            .animation(.snappy(extraBounce: 1.0), value: showAuthButtons)
                            .padding(.bottom)
                        }

                        if showAuthButtons {
                            VStack(spacing: 8) {
                                Button {
                                    onAppleSignIn()
                                } label: {
                                    HStack(alignment: .center) {
                                        Image(systemName: "apple.logo")
                                            .foregroundStyle(.white)
                                        Text("Continue with Apple")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .frame(height: 55)
                                    .background(.black, in: .capsule)
                                }

                                Button {
                                    onLogin()
                                } label: {
                                    Text("Log in")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .frame(height: 55)
                                        .background(.white, in: .capsule)
                                }

                                Button {
                                    onSignUp()
                                } label: {
                                    Text("Sign up")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .frame(height: 55)
                                        .overlay(
                                            Capsule()
                                                .stroke(.white.opacity(0.4), lineWidth: 1.5)
                                        )
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom)
                            .opacity(showAuthButtons ? 1 : 0)
                            .offset(y: showAuthButtons ? 0 : 100)
                            .animation(.snappy(extraBounce: 1.0), value: showAuthButtons)
                        }
                    }
                    .layoutPriority(1)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        bottomContentHeight = newHeight
                    }
                }
                .safeAreaPadding(15)
            }
        }
        .onReceive(timer) { _ in
            currentScrollOffset += 0.45
            scrollPosition.scrollTo(x: currentScrollOffset)
        }
        .task {
            try? await Task.sleep(for: .seconds(0.35))
            
            withAnimation(.smooth(duration: 0.75, extraBounce: 0)) {
                initialAnimation = true
            }
            
            withAnimation(.smooth(duration: 2.5, extraBounce: 0).delay(0.3)) {
                titleProgress = 1
            }
        }
    }

    private var contentSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 40
    }

    private var cardToScreenRatio: CGFloat {
        switch dynamicTypeSize {
        case ...DynamicTypeSize.large:
            return 0.50
        case ...DynamicTypeSize.xLarge:
            return 0.44
        case ...DynamicTypeSize.xxLarge:
            return 0.38
        case ...DynamicTypeSize.xxxLarge:
            return 0.32
        case ...DynamicTypeSize.accessibility2:
            return 0.24
        default:
            return 0.16
        }
    }

    private func carouselHeight(in containerHeight: CGFloat) -> CGFloat {
        let reserved = bottomContentHeight + (contentSpacing * 2) + 32
        let available = max(containerHeight - reserved, 80)
        return min(containerHeight * cardToScreenRatio, available)
    }
    
    @ViewBuilder
    private func AmbientBackground() -> some View {
        GeometryReader {
            let size = $0.size
            
            ZStack {
                ForEach(cards) { card in
                    Image(card.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .frame(width: size.width, height: size.height)
                        .opacity(activeCard?.id == card.id ? 1 : 0)
                }
                
                Rectangle()
                    .fill(.black.opacity(0.45))
                    .ignoresSafeArea()
            }
            .compositingGroup()
            .blur(radius: 90, opaque: true)
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private func CarouselCardView(_ card: Card, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        GeometryReader {
            let size = $0.size
            
            Image(card.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipShape(.rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.4), radius: 10, x: 1, y: 0)
        }
        .frame(width: cardWidth, height: cardHeight)
        .scrollTransition(.interactive.threshold(.centered), axis: .horizontal) { content,
            phase in
            content
                .offset(y: phase == .identity ? -10 : 0)
                .rotationEffect(.degrees(phase.value * 5), anchor: .bottom)
        }
    }
    
}

#Preview {
    IntroPage(
        onGetStarted: {
            print("Get Started tapped")
        },
        onAppleSignIn: {
            print("Apple Sign In tapped")
        },
        onLogin: {
            print("Login tapped")
        },
        onSignUp: {
            print("Sign Up tapped")
        }
    )
}

extension View {
    func blurOpacityEffect(_ show: Bool) -> some View {
        self
            .blur(radius: show ? 0 : 2)
            .opacity(show ? 1 : 0)
            .scaleEffect(show ? 1 : 0.9)

    }
}
