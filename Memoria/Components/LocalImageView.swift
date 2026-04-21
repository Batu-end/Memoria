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
                    .cornerRadius(12)
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
                    
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("No Technical Setup Attached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        
        // Push heavy file I/O to background thread
        let data = await Task.detached(priority: .userInitiated) {
            LocalAttachmentService.shared.loadImageData(id: id)
        }.value
        
        if let data = data, let nsImage = NSImage(data: data) {
            loadedImage = Image(nsImage: nsImage)
        } else {
            loadedImage = nil
        }
        
        isLoading = false
    }
}
