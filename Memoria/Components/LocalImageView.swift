//
//  LocalImageView.swift
//  Memoria
//
//  Created by Memoria on 4/18/26.
//

import SwiftUI

/// Safely attempts to load a massive Image from the local filesystem to avoid SwiftData binary blob lag.
struct LocalImageView: View {
    let attachmentId: String?
    
    @State private var loadedImage: Image? = nil
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = loadedImage {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isLoading && attachmentId != nil {
                // Loading container
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    ProgressView()
                }
            } else {
                // Empty Fallback (No attachment assigned or deleted)
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.16))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("No Attachment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Drop an image here to remember your setup.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .task(id: attachmentId) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let id = attachmentId else {
            loadedImage = nil
            isLoading = false
            return
        }
        
        isLoading = true
        
        // Push heavy file I/O off the cooperative thread pool
        let data: Data? = await Task(priority: .userInitiated) {
            LocalAttachmentService.shared.loadImageData(id: id)
        }.value
        
        #if os(macOS)
        if let data = data, let nsImage = NSImage(data: data) {
            loadedImage = Image(nsImage: nsImage)
        } else {
            loadedImage = nil
        }
        #else
        if let data = data, let uiImage = UIImage(data: data) {
            loadedImage = Image(uiImage: uiImage)
        } else {
            loadedImage = nil
        }
        #endif
        
        isLoading = false
    }
}
