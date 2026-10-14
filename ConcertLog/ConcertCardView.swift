import SwiftUI

struct ConcertCardView: View {
    let initial: Concert
    var concert: Concert {
        store.concerts.first(where: { $0.id == initial.id }) ?? initial
    }
    @State private var showEdit = false
    @Environment(ConcertStore.self) private var store

    var body: some View {
        VStack {
            ZStack (alignment: .bottomLeading) {
                if let photoName = concert.photoName,
                   let ui = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: photoName).path) {
                    Color.clear
                        .overlay {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                } else {
                    LinearGradient (
                        colors: [Color.btsPink, Color.btsBackground],
                        startPoint: .top,
                        endPoint: UnitPoint.bottom)
                }
                LinearGradient(colors: [Color.clear, Color.btsBackground], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading) {
                    let been = concert.isPast ? "BEEN TO SHOW" : "UPCOMING"
                    Text(been)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.btsLime)
                        .clipShape(Capsule())
                    Text(concert.artist).font(.system(size: 34, weight: .heavy))
                    Text(concert.city).foregroundStyle(.white.opacity(0.8))
                    Text(concert.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
            }
            .frame(height: 333)
            .ignoresSafeArea(edges: .top)
           
            HStack(spacing: 16) {
                HStack {
                    if let rating = concert.rating {
                        HStack {
                            ForEach(0..<Int(rating.rounded()), id: \.self) { _ in
                                Image(systemName: "star.fill")
                            }
                            .foregroundStyle(Color.btsPink)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 21, weight: .bold))
                                .fixedSize()
                        }
                    }
                }
                Spacer()
                
                HStack {
                    ForEach(concert.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.btsPink, Color.btsViolet],
                                    startPoint: .leading,
                                    endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
    
            .padding()
            if let comment = concert.comment {
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.btsPink)
                        .frame(width: 4)
                    
                    Text("«\(comment)»")
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .background(Color.btsCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Spacer()
            
            Button {
                showEdit = true
            } label: {
                Text("Изменить")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .padding(.bottom, 3)
                    .background(Color.btsCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(                                     
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .sheet(isPresented: $showEdit) { NewConcertView(concert: concert) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.btsBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    ConcertCardView(initial: sampleConcerts[0])
        .environment(ConcertStore())
}
