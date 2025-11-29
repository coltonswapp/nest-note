//
//  IntroPage.swift
//  AppleInvites
//
//  Created by Luis Filipe Pedroso on 27/03/25.
//

import SwiftUI

struct IntroPage: View {
    
    static let cardWHRatio: CGFloat = 1.77
    static let cardToScreenRatio: CGFloat = 0.5
    
    @State private var activeCard: Card? = cards.first
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var currentScrollOffset: CGFloat = 0
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .default).autoconnect()
    @State private var initialAnimation: Bool = false
    @State private var titleProgress: CGFloat = 0
    @State private var scrollPhase: ScrollPhase = .idle
    
    var onGetStarted: () -> Void
    
    init(onGetStarted: @escaping () -> Void) {
        self.onGetStarted = onGetStarted
    }
    
    var body: some View {
        ZStack {
            AmbientBackground()
                .animation(.easeInOut(duration: 1), value: activeCard)
            
            VStack(spacing: 40) {
                Spacer()
                
                InfiniteScrollView {
                    ForEach(cards) { card in
                        CarouselCardView(card)
                    }
                }
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
                        let activeIndex = Int((currentScrollOffset / ((UIScreen.main.bounds.height * IntroPage.cardToScreenRatio) / IntroPage.cardWHRatio)).rounded()) % cards.count
                        activeCard = cards[activeIndex]
                    }
                }
                .visualEffect { [initialAnimation] content, proxy in
                        content
                        .offset(y: !initialAnimation ? -(proxy.size.height + 200) : 0)
                }
                
                Spacer()
                
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
                    
                    Text("Keep your sitter informed, your family safe. \nEverything they need to know, right when they need it.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.secondary)
                        .blurOpacityEffect(initialAnimation)
                }
                
                Button {
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
                .padding(.bottom)
                
            }
            .safeAreaPadding(15)
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
    private func CarouselCardView(_ card: Card) -> some View {
        GeometryReader {
            let size = $0.size
            
            Image(card.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipShape(.rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.4), radius: 10, x: 1, y: 0)
        }
        .frame(width: (UIScreen.main.bounds.height * IntroPage.cardToScreenRatio) / IntroPage.cardWHRatio, height: UIScreen.main.bounds.height * IntroPage.cardToScreenRatio)
        .scrollTransition(.interactive.threshold(.centered), axis: .horizontal) { content,
            phase in
            content
                .offset(y: phase == .identity ? -10 : 0)
                .rotationEffect(.degrees(phase.value * 5), anchor: .bottom)
        }
    }
    
}

extension View {
    func blurOpacityEffect(_ show: Bool) -> some View {
        self
            .blur(radius: show ? 0 : 2)
            .opacity(show ? 1 : 0)
            .scaleEffect(show ? 1 : 0.9)
        
    }
}
