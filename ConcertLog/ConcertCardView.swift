import SwiftUI

struct ConcertCardView: View {
    let concert: Concert

    var body: some View {
        VStack {
            Text(concert.artist).font(.title)
            Text(concert.city).foregroundStyle(.secondary)
            Text(concert.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))
                .foregroundStyle(.secondary)
            if let rating = concert.rating {
                HStack {
                    ForEach(0..<Int(rating.rounded()), id: \.self) { _ in
                        Image(systemName: "star.fill")
                    }
                }
                .foregroundStyle(Color.btsPink)
            }
            if let comment = concert.comment {
                Text(comment)
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack {
                ForEach(concert.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.btsPink.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
    }
}

#Preview {
    ConcertCardView(concert: sampleConcerts[0])
}
