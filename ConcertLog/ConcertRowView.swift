import SwiftUI

struct ConcertRowView: View {
    let concert: Concert
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors : [.pink, .purple, .blue],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                ))
                .frame(width: 48, height: 48)
            VStack (alignment: .leading) {
                Text(concert.artist).font(.headline)
                Text("\(concert.city) · \(concert.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let rating = concert.rating {
                Text("★ " + String(format: "%.1f", rating)).foregroundStyle(.pink)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(.pink.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 23)
    }
}

#Preview {
    ConcertRowView(concert: sampleConcerts[0])
}

