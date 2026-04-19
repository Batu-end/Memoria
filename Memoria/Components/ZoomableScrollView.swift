//
//  ZoomableScrollView.swift
//  Memoria
//
//  Created by Memoria on 4/18/26.
//

import SwiftUI
import AppKit

/// A high-performance pro-grade image viewer for macOS.
/// Bridges NSScrollView to provide native pinch-to-zoom, elastic bouncing,
/// and automatic edge-centering that pure SwiftUI currently lacks.
struct ZoomableScrollView: NSViewRepresentable {
    let attachmentId: String?
    @Binding var resetTrigger: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        
        // 1. Configure standard Mac Pro behavior
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 10.0
        scrollView.backgroundColor = .black
        
        // 2. Setup the image container
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.translatesAutoresizingMaskIntoConstraints = true
        
        // 3. Bind
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
        
        // Fetch data if attachment exists
        if let data = LocalAttachmentService.shared.loadImageData(id: id),
           let nsImage = NSImage(data: data) {
            
            if let imageView = nsView.documentView as? NSImageView {
                if imageView.image != nsImage {
                    imageView.image = nsImage
                    
                    // Match the frame to the scroll view viewport initially
                    // This makes magnification 1.0 = "Fit to Screen"
                    imageView.frame = nsView.bounds
                }
            }
        }
    }
}
