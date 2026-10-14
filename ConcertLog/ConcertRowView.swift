import SwiftUI

struct ConcertRowView: View {
    let concert: Concert
    
    var body: some View {
        HStack {
            if let photoName = concert.photoNames.first, let ui = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: photoName).path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors : [Color.btsPink, Color.btsViolet],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ))
                    .frame(width: 48, height: 48)
            }
            VStack (alignment: .leading) {
                Text(concert.artist).font(.headline)
                Text("\(concert.city) · \(concert.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let rating = concert.rating {
                Text("★ " + String(format: "%.1f", rating)).foregroundStyle(Color.btsPink)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Color.btsPink.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 23)
    }
}

#Preview {
    ConcertRowView(concert: sampleConcerts[0])
}

