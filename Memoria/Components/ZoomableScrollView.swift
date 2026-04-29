//
//  ZoomableScrollView.swift
//  Memoria

import SwiftUI

#if os(macOS)
import AppKit

/// A high-performance pro-grade image viewer for macOS.
/// Bridges NSScrollView to provide native pinch-to-zoom, elastic bouncing,
/// and automatic edge-centering that pure SwiftUI currently lacks.
struct ZoomableScrollView: NSViewRepresentable {
    let attachmentId: String?
    @Binding var resetTrigger: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 10.0
        scrollView.backgroundColor = .black

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.translatesAutoresizingMaskIntoConstraints = true

        scrollView.documentView = imageView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if resetTrigger {
            DispatchQueue.main.async {
                nsView.setMagnification(1.0, centeredAt: .zero)
                resetTrigger = false
            }
        }

        guard let id = attachmentId else { return }

        if let data = LocalAttachmentService.shared.loadImageData(id: id),
           let nsImage = NSImage(data: data) {
            if let imageView = nsView.documentView as? NSImageView {
                if imageView.image != nsImage {
                    imageView.image = nsImage
                    imageView.frame = nsView.bounds
                }
            }
        }
    }
}

#else
import UIKit

struct ZoomableScrollView: UIViewRepresentable {
    let attachmentId: String?
    @Binding var resetTrigger: Bool

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 10.0
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if resetTrigger {
            DispatchQueue.main.async {
                scrollView.setZoomScale(1.0, animated: true)
                resetTrigger = false
            }
        }

        guard let id = attachmentId else { return }

        if let data = LocalAttachmentService.shared.loadImageData(id: id),
           let uiImage = UIImage(data: data) {
            let iv = context.coordinator.imageView
            if iv?.image != uiImage {
                iv?.image = uiImage
                iv?.frame = CGRect(origin: .zero, size: uiImage.size)
                scrollView.contentSize = uiImage.size
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}

#endif
