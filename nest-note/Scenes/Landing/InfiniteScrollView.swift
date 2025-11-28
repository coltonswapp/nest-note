//
//  InfiniteScrollView.swift
//  AppleInvites
//
//  Created by Luis Filipe Pedroso on 27/03/25.
//

import SwiftUI

struct InfiniteScrollView<Content: View>: View {
    var spacing: CGFloat = 30
    var scaleFactor: CGFloat = 1.0
    @ViewBuilder var content: Content

    @State private var contentSize: CGSize = .zero
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            
            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    Group(subviews: content) { colletion in
                        HStack(spacing: spacing) {
                            ForEach(colletion) { view in
                                view
                            }
                        }
                        .onGeometryChange(for: CGSize.self) {
                            $0.size
                        } action: { newValue in
                            contentSize = .init(width: newValue.width + spacing, height: newValue.height)
                        }
                        
                        let repeatingCount = colletion.count > 0 ? colletion.count * 4 : 0

                        HStack(spacing: spacing) {
                            ForEach(0..<repeatingCount, id: \.self) { index in
                                let view = Array(colletion)[index % max(colletion.count, 1)]
                                view
                            }
                        }
                    }
                }
                .background(InfiniteScrollHelper(contentSize: $contentSize, scaleFactor: scaleFactor, declarationRate: .constant(.fast)))
            }
        }
    }
}

fileprivate struct InfiniteScrollHelper: UIViewRepresentable {
    @Binding var contentSize: CGSize
    var scaleFactor: CGFloat = 1.0
    @Binding var declarationRate: UIScrollView.DecelerationRate
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(declarationRate: declarationRate, contentSize: contentSize, scaleFactor: scaleFactor)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        DispatchQueue.main.async {
            if let scrollView = view.scrollView {
                context.coordinator.defaultDelegate = scrollView.delegate
                scrollView.decelerationRate = declarationRate
                scrollView.delegate = context.coordinator
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        context.coordinator.declarationRate = declarationRate
        context.coordinator.contentSize = contentSize
        context.coordinator.scaleFactor = scaleFactor
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var declarationRate: UIScrollView.DecelerationRate
        var contentSize: CGSize
        var scaleFactor: CGFloat

        init(declarationRate: UIScrollView.DecelerationRate, contentSize: CGSize, scaleFactor: CGFloat) {
            self.declarationRate = declarationRate
            self.contentSize = contentSize
            self.scaleFactor = scaleFactor
        }
        
        weak var defaultDelegate: UIScrollViewDelegate?
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            scrollView.decelerationRate = declarationRate

            let minX = scrollView.contentOffset.x

            // Small buffer (half card width) to prevent premature jumping while maintaining infinite scroll
            let buffer = contentSize.width * 0.15

            if minX > contentSize.width + buffer {
                scrollView.contentOffset.x -= contentSize.width
            }

            if minX < -buffer {
                scrollView.contentOffset.x += contentSize.width
            }

            defaultDelegate?.scrollViewDidScroll?(scrollView)
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            defaultDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            defaultDelegate?.scrollViewDidEndDecelerating?(scrollView)
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            defaultDelegate?.scrollViewWillBeginDragging?(scrollView)
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            defaultDelegate?.scrollViewWillEndDragging?(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
        }
    }
}

extension UIView {
    var scrollView: UIScrollView? {
        if let superview, superview is UIScrollView {
            return superview as? UIScrollView
        }
        
        return superview?.scrollView
    }
}
