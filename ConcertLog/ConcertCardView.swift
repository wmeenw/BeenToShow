import SwiftUI
import AVKit

struct ConcertCardView: View {
    let initial: Concert
    var concert: Concert {
        store.concerts.first(where: { $0.id == initial.id }) ?? initial
    }
    @State private var showEdit = false
    @State private var selectedPhotoIndex: Int? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(ConcertStore.self) private var store

    private var mediaCount: Int { concert.photoNames.count + concert.videoNames.count }

    private var photoViewer: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: Binding(
                get: { selectedPhotoIndex ?? 0 },
                set: { selectedPhotoIndex = $0 }
            )) {
                ForEach(Array(concert.photoNames.enumerated()), id: \.offset) { index, name in
                    if let ui = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: name).path) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
                ForEach(Array(concert.videoNames.enumerated()), id: \.offset) { offset, name in
                    VideoPage(url: URL.documentsDirectory.appending(path: name), isCurrent: selectedPhotoIndex == concert.photoNames.count + offset)
                        .tag(concert.photoNames.count + offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button {
                selectedPhotoIndex = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.system(size: 28))
            }
            .padding()
        }
    }

    private var ratingView: some View {
        HStack {
            if let rating = concert.rating {
                HStack {
                    ForEach(0..<Int(rating.rounded()), id: \.self) { _ in
                        Image(systemName: "star.fill")
                    }
                    .foregroundStyle(Color.btsPink)
                    Text(String(format: "%.1f", rating))
                        .font(.unbounded(21, .bold))
                        .fixedSize()
                }
            }
        }
    }
    
    private func tagPill(_ tag: String) -> some View {
        Text(tag)
            .font(.onest(13, .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
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
    
    var body: some View {
        VStack {
            ZStack (alignment: .bottomLeading) {
                if let photoName = concert.photoNames.first,
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
                    Text(concert.artist).font(.unbounded(26, .bold)).lineLimit(2).minimumScaleFactor(0.6)
                    Text(concert.city).foregroundStyle(.white.opacity(0.8))
                    Text(concert.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
            }
            .frame(height: 333)
            .ignoresSafeArea(edges: .top)
           
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    ratingView
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(concert.tags, id: \.self) { tag in
                            tagPill(tag)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    ratingView
                    TagFlowLayout(spacing: 8) {
                        ForEach(concert.tags, id: \.self) { tag in
                            tagPill(tag)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            if mediaCount > 1 || !concert.videoNames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("МОИ ФОТО И ВИДЕО")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.45))
                        Spacer()
                        Button {
                            selectedPhotoIndex = 0
                        } label: {
                            Text("Все \(mediaCount)")
                                .font(.onest(13, .medium))
                                .foregroundStyle(Color.btsPink)
                                .padding(.vertical, 8)
                                .padding(.leading, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(concert.videoNames.enumerated()), id: \.offset) { offset, name in
                                Button {
                                    selectedPhotoIndex = concert.photoNames.count + offset
                                } label: {
                                    VideoThumbnail(url: URL.documentsDirectory.appending(path: name))
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(Array(concert.photoNames.enumerated()), id: \.offset) { index, name in
                                if let ui = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: name).path) {
                                    Button {
                                        selectedPhotoIndex = index
                                    } label: {
                                        Image(uiImage: ui)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
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
                    .font(.onest(17, .semibold))
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
        .onChange(of: store.concerts.contains { $0.id == initial.id }) { _, exists in
            if !exists {
                dismiss()
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedPhotoIndex != nil },
            set: { if !$0 { selectedPhotoIndex = nil } }
        )) {
            photoViewer
        }
    }
}

private struct VideoThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Color.btsCard
            .frame(width: 100, height: 100)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .task { image = await VideoTools.thumbnail(of: url) }
    }
}

private struct VideoPage: View {
    let url: URL
    let isCurrent: Bool
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                Color.black
            }
        }
        .onAppear { if player == nil { player = AVPlayer(url: url) } }
        .onChange(of: isCurrent) { _, current in
            if !current { player?.pause() }
        }
        .onDisappear { player?.pause() }
    }
}

#Preview {
    ConcertCardView(initial: sampleConcerts[0])
        .environment(ConcertStore())
}
