import Foundation
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Концерты", systemImage: "music.note")
                }
            
            WaitingScreen()
                .tabItem {
                    Label("Ждём", systemImage: "clock")
                }
            
            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person")
                }
        }
        .tint(Color.btsPink)
    }
}

private struct FavoriteArtist: Identifiable {
    let name: String
    let count: Int
    let photoName: String?
    var id: String { name }
}

struct ProfileView: View {
    @Environment(ConcertStore.self) private var store
    @AppStorage("profileName") private var name = "Маша"
    @AppStorage("remindSale") private var remindSale = true
    @AppStorage("remindImpression") private var remindImpression = true
    @AppStorage("remindLead") private var remindLead = "за день"
    @AppStorage("halfStars") private var halfStars = false
    @State private var showNameAlert = false
    @State private var nameDraft = ""
    @State private var showDeleteAll = false
    @State private var showSoon = false
    
    private let levels: [(threshold: Int, title: String, genitive: String)] = [
        (0, "Новичок", "Новичка"),
        (3, "Слушатель", "Слушателя"),
        (8, "Фанатка", "Фанатки"),
        (20, "Легенда", "Легенды")
    ]
    
    private var past: [Concert] {
        store.concerts.filter { $0.isPast }
    }
    
    private var year: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    private var yearConcerts: [Concert] {
        past.filter { Calendar.current.component(.year, from: $0.date) == year }
    }
    
    private var yearCities: Int {
        Set(yearConcerts.map { $0.city }).count
    }
    
    private var yearRating: Double {
        let ratings = yearConcerts.compactMap { $0.rating }
        if ratings.isEmpty {
            return 0
        }
        return ratings.reduce(0, +) / Double(ratings.count)
    }
    
    private var levelIndex: Int {
        var index = 0
        for (i, level) in levels.enumerated() where past.count >= level.threshold {
            index = i
        }
        return index
    }
    
    private var favoriteArtists: [FavoriteArtist] {
        var counts: [String: Int] = [:]
        for concert in past {
            counts[concert.artist, default: 0] += 1
        }
        let sorted = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return lhs.key < rhs.key
        }
        return sorted.prefix(3).map { item in
            let photo = past
                .filter { $0.artist == item.key && !$0.photoNames.isEmpty }
                .sorted { $0.date > $1.date }
                .first?.photoNames.first
            return FavoriteArtist(name: item.key, count: item.value, photoName: photo)
        }
    }
    
    private var favoriteTags: [String] {
        var counts: [String: Int] = [:]
        for concert in past {
            for tag in concert.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return lhs.key < rhs.key
        }.prefix(3).map { $0.key }
    }
    
    private var geography: [String] {
        var counts: [String: Int] = [:]
        for concert in past {
            counts[concert.city, default: 0] += 1
        }
        return counts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return lhs.key < rhs.key
        }.map { $0.key }
    }
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.45))
    }
    
    private var header: some View {
        HStack {
            sectionLabel("ПРОФИЛЬ")
            Spacer()
            Button {
                nameDraft = name
                showNameAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                    Text("Изменить")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var identity: some View {
        let level = levels[levelIndex]
        return HStack(spacing: 16) {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Color.white)
                .frame(width: 76, height: 76)
                .background(
                    LinearGradient(
                        colors: [Color.btsPink, Color.btsViolet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.btsPink.opacity(0.5), radius: 16)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Color.white)
                Text("УРОВЕНЬ · \(level.title.uppercased())")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.btsPink)
            }
            Spacer()
        }
    }
    
    private var levelProgress: some View {
        let count = past.count
        let next = levelIndex + 1 < levels.count ? levels[levelIndex + 1] : nil
        let fraction: Double = {
            if let next {
                return min(1, Double(count) / Double(next.threshold))
            }
            return 1
        }()
        return VStack(spacing: 8) {
            HStack {
                Text("\(count) \(plural(count, one: "концерт", few: "концерта", many: "концертов"))")
                Spacer()
                if let next {
                    Text("до «\(next.genitive)» ещё \(next.threshold - count)")
                } else {
                    Text("максимальный уровень")
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.white.opacity(0.55))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.btsPink, Color.btsViolet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
    }
    
    private func figure(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .heavy))
            Text(title)
                .font(.system(size: 13))
                .opacity(0.85)
        }
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var yearCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ТВОЙ \(year) В ЦИФРАХ")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.85))
            HStack {
                figure("\(yearConcerts.count)", plural(yearConcerts.count, one: "концерт", few: "концерта", many: "концертов"))
                figure("\(yearCities)", plural(yearCities, one: "город", few: "города", many: "городов"))
                figure(String(format: "%.1f", yearRating), "оценка")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.btsPink, Color.btsViolet],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    private func artistAvatar(_ photoName: String?) -> some View {
        Group {
            if let photoName,
               let ui = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: photoName).path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.btsPink, Color.btsViolet],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
    
    private var artistsBlock: some View {
        let maxCount = favoriteArtists.map { $0.count }.max() ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ЛЮБИМЫЕ АРТИСТЫ")
            VStack(spacing: 14) {
                ForEach(favoriteArtists) { artist in
                    HStack(spacing: 12) {
                        artistAvatar(artist.photoName)
                        VStack(spacing: 6) {
                            HStack {
                                Text(artist.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Spacer()
                                Text("\(artist.count) \(plural(artist.count, one: "раз", few: "раза", many: "раз"))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.btsPink)
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.btsPink, Color.btsViolet],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: proxy.size.width * Double(artist.count) / Double(maxCount))
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
                if favoriteArtists.isEmpty {
                    Text("Пока нет прошедших концертов")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(Color.btsCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private func outlinePill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.6), lineWidth: 1)
            )
    }
    
    private var vibeBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ЛЮБИМЫЙ ВАЙБ")
            if favoriteTags.isEmpty {
                Text("Пока нет тегов")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.5))
            } else {
                TagFlowLayout(spacing: 8) {
                    ForEach(favoriteTags, id: \.self) { tag in
                        outlinePill(tag, color: Color.btsPink)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var geographyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ГЕОГРАФИЯ")
            TagFlowLayout(spacing: 8) {
                ForEach(geography, id: \.self) { city in
                    outlinePill(city, color: Color.btsViolet)
                }
                Text("+ следующий")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.btsViolet.opacity(0.8))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(Color.btsViolet.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.btsCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private var achievements: [(value: String, title: String, unlocked: Bool)] {
        let photos = past.filter { !$0.photoNames.isEmpty }.count
        let cities = Set(past.map { $0.city }).count
        let perfect = past.contains { ($0.rating ?? 0) >= 5 }
        let maxArtistVisits = favoriteArtists.map { $0.count }.max() ?? 0
        let distinctTags = Set(past.flatMap { $0.tags }).count
        let oneYear: TimeInterval = 365 * 24 * 60 * 60
        let withUs = past.map { $0.date }.min().map { Date().timeIntervalSince($0) >= oneYear } ?? false
        return [
            ("1", "первый\nконцерт", past.count >= 1),
            ("5", "концертов", past.count >= 5),
            ("10", "концертов", past.count >= 10),
            ("25", "концертов", past.count >= 25),
            ("3", "городов", cities >= 3),
            ("5", "городов", cities >= 5),
            ("10", "городов", cities >= 10),
            ("★", "идеал 5.0", perfect),
            ("10", "фото-архив", photos >= 10),
            ("3", "с одним\nартистом", maxArtistVisits >= 3),
            ("5", "видов\nвайба", distinctTags >= 5),
            ("1", "год\nв дневнике", withUs)
        ]
    }

    private var achievementsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("ДОСТИЖЕНИЯ")
                Spacer()
                Text("все \(achievements.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.btsPink)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(achievements.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 4) {
                            Text(item.value)
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(Color.btsPink)
                            Text(item.title)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 80, height: 84)
                        .background(Color.btsCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .opacity(item.unlocked ? 1 : 0.35)
                    }
                }
            }
        }
    }
    
    private func settingsRow<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.white)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func valueRow(_ title: String, value: String) -> some View {
        Button {
            showSoon = true
        } label: {
            settingsRow(title) {
                Text("\(value) ›")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
    
    private var remindersBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("НАПОМИНАНИЯ")
            VStack(spacing: 0) {
                settingsRow("Старт продажи билетов") {
                    Toggle("", isOn: $remindSale)
                        .labelsHidden()
                        .tint(Color.btsLime)
                }
                Divider().overlay(Color.white.opacity(0.08))
                settingsRow("Записать впечатление") {
                    Toggle("", isOn: $remindImpression)
                        .labelsHidden()
                        .tint(Color.btsLime)
                }
                Divider().overlay(Color.white.opacity(0.08))
                Menu {
                    Button("за неделю") { remindLead = "за неделю" }
                    Button("за день") { remindLead = "за день" }
                    Button("за час") { remindLead = "за час" }
                } label: {
                    settingsRow("Заранее напоминать") {
                        Text("\(remindLead) ›")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
            }
            .background(Color.btsCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private var dataBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ДАННЫЕ И ПРИЛОЖЕНИЕ")
            VStack(spacing: 0) {
                valueRow("Экспорт дневника", value: "PDF")
                Divider().overlay(Color.white.opacity(0.08))
                valueRow("Резервная копия", value: "iCloud")
                Divider().overlay(Color.white.opacity(0.08))
                settingsRow("Половинки звёзд") {
                    Toggle("", isOn: $halfStars)
                        .labelsHidden()
                        .tint(Color.btsLime)
                }
                Divider().overlay(Color.white.opacity(0.08))
                Button {
                    showDeleteAll = true
                } label: {
                    settingsRow("Удалить все данные") {
                        Text("›")
                            .foregroundStyle(Color.btsPink)
                    }
                }
                .buttonStyle(.plain)
                Divider().overlay(Color.white.opacity(0.08))
                settingsRow("Версия") {
                    Text("0.1 (MVP)")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .background(Color.btsCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                identity
                levelProgress
                yearCard
                artistsBlock
                vibeBlock
                geographyBlock
                achievementsBlock
                remindersBlock
                dataBlock
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.btsBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert("Твоё имя", isPresented: $showNameAlert) {
            TextField("Имя", text: $nameDraft)
            Button("Сохранить") {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    name = trimmed
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Скоро", isPresented: $showSoon) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Эта функция появится позже.")
        }
        .confirmationDialog("Удалить все данные?", isPresented: $showDeleteAll, titleVisibility: .visible) {
            Button("Удалить все концерты", role: .destructive) {
                store.deleteAll()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Все концерты и фото будут удалены без возможности восстановления.")
        }
    }
}

#Preview {
    ProfileView()
        .environment(ConcertStore())
}
