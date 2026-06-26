//
//  VerticalInfiniteScrollView.swift
//  nest-note
//

import SwiftUI

struct VerticalInfiniteScrollView<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    @State private var contentSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ScrollView(.vertical) {
                VStack(spacing: spacing) {
                    Group(subviews: content) { collection in
                        VStack(spacing: spacing) {
                            ForEach(collection) { view in
                                view
                            }
                        }
                        .onGeometryChange(for: CGSize.self) {
                            $0.size
                        } action: { newValue in
                            contentSize = .init(width: newValue.width, height: newValue.height + spacing)
                        }

                        let averageHeight = contentSize.height / CGFloat(max(collection.count, 1))
                        let repeatingCount = contentSize.height > 0
                            ? Int((size.height / averageHeight).rounded()) + 1
                            : 1

                        VStack(spacing: spacing) {
                            ForEach(0..<repeatingCount, id: \.self) { index in
                                let view = Array(collection)[index % collection.count]
                                view
                            }
                        }
                    }
                }
                .background(
                    VerticalInfiniteScrollHelper(
                        contentSize: $contentSize,
                        declarationRate: .constant(.fast)
                    )
                )
            }
        }
    }
}

private struct VerticalInfiniteScrollHelper: UIViewRepresentable {
    @Binding var contentSize: CGSize
    @Binding var declarationRate: UIScrollView.DecelerationRate

    func makeCoordinator() -> Coordinator {
        Coordinator(declarationRate: declarationRate, contentSize: contentSize)
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

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.declarationRate = declarationRate
        context.coordinator.contentSize = contentSize
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var declarationRate: UIScrollView.DecelerationRate
        var contentSize: CGSize

        init(declarationRate: UIScrollView.DecelerationRate, contentSize: CGSize) {
            self.declarationRate = declarationRate
            self.contentSize = contentSize
        }

        weak var defaultDelegate: UIScrollViewDelegate?

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            scrollView.decelerationRate = declarationRate

            let minY = scrollView.contentOffset.y

            if minY > contentSize.height {
                scrollView.contentOffset.y -= contentSize.height
            }

            if minY < 0 {
                scrollView.contentOffset.y += contentSize.height
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

        func scrollViewWillEndDragging(
            _ scrollView: UIScrollView,
            withVelocity velocity: CGPoint,
            targetContentOffset: UnsafeMutablePointer<CGPoint>
        ) {
            defaultDelegate?.scrollViewWillEndDragging?(
                scrollView,
                withVelocity: velocity,
                targetContentOffset: targetContentOffset
            )
        }
    }
}
