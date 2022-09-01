//
//  RefreshableScrollView.swift
//  RefreshableScrollView
//
//  Created by Mathijs Bernson on 03/03/2022.
//

import SwiftUI
import UIKit

/// A custom scroll view that supports pull to refresh using the `refreshable()` modifier.
public struct RefreshableScrollView<Content: View>: View {
  @Binding var isRefreshing: Bool
  let refreshControl: () -> UIRefreshControl
  @ViewBuilder let content: () -> Content

  public init(
    isRefreshing: Binding<Bool>,
    refreshControl: @autoclosure @escaping () -> UIRefreshControl = .init(),
    @ViewBuilder content: @escaping () -> Content
  ) {
    self._isRefreshing = isRefreshing
    self.refreshControl = refreshControl
    self.content = content
  }

  public var body: some View {
    GeometryReader { proxy in
      ScrollViewControllerRepresentable(isRefreshing: _isRefreshing, refreshControl: refreshControl()) {
        content()
          .frame(width: proxy.size.width)
      }
    }
  }
}

struct ScrollViewControllerRepresentable<Content: View>: UIViewControllerRepresentable {
  @Binding var isRefreshing: Bool
  let refreshControl: UIRefreshControl
  @ViewBuilder let content: () -> Content
  @Environment(\.refresh) private var action

  init(
    isRefreshing: Binding<Bool>,
    refreshControl: UIRefreshControl,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self._isRefreshing = isRefreshing
    self.refreshControl = refreshControl
    self.content = content
  }

  func makeUIViewController(context: Context) -> ScrollViewController<Content> {
    let viewController = ScrollViewController(
      refreshControl: refreshControl,
      view: content()
    )
    viewController.onRefresh = {
      refresh()
    }
    return viewController
  }

  func updateUIViewController(_ viewController: ScrollViewController<Content>, context: Context) {
    viewController.hostingController.rootView = content()
    viewController.hostingController.view.setNeedsUpdateConstraints()

    if isRefreshing {
      viewController.refreshControl.beginRefreshing()
      let refreshHeight = viewController.refreshControl.frame.size.height
      if (viewController.scrollView.contentOffset.y > -refreshHeight) {
          viewController.scrollView.setContentOffset(CGPoint(x: 0, y: -refreshHeight), animated: true)
      }
    } else {
      viewController.refreshControl.endRefreshing()
    }
  }

  func refresh() {
    Task {
      await action?()
    }
  }
}

class ScrollViewController<Content: View>: UIViewController, UIScrollViewDelegate {
  let scrollView = UIScrollView()
  let refreshControl: UIRefreshControl
  let hostingController: UIHostingController<Content>

  var onRefresh: (() -> Void)?

  init(refreshControl: UIRefreshControl, view: Content) {
    self.refreshControl = refreshControl
    hostingController = .init(rootView: view)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = scrollView
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)

    scrollView.refreshControl = refreshControl
    scrollView.delegate = self

    hostingController.willMove(toParent: self)

    scrollView.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
    ])

    // `addChild` must be called *after* the layout constraints have been set, or a layout bug will occur
    addChild(hostingController)
    hostingController.didMove(toParent: self)
    hostingController.view.backgroundColor = .clear
  }

  @objc func didPullToRefresh(_ sender: UIRefreshControl) {
    onRefresh?()
  }
}
