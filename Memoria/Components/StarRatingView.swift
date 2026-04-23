import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var fontSize: CGFloat = 20
    var color: Color = Color(red: 1.0, green: 0.72, blue: 0.0) // Premium Gold
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: fontSize))
                    .foregroundStyle(index <= rating ? color : color.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            rating = index
                        }
                    }
            }
        }
    }
}

#Preview {
    @Previewable @State var rating = 3
    return StarRatingView(rating: $rating)
        .padding()
        .background(Color.black)
}
