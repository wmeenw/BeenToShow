import Foundation
import SwiftUI

struct WaitingScreen: View {
    @Environment(ConcertStore.self) private var store
    @State private var showForm = false
    
    var upcoming: [Concert] {
        store.concerts
            .filter { !$0.isPast }
            .sorted { $0.date < $1.date }
    }
    
    private func daysLeft(_ concert: Concert) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: concert.date)).day ?? 0
        return max(0, days)
    }
    
    private func heroCard(_ concert: Concert) -> some View {
        let days = daysLeft(concert)
        return NavigationLink {
            WaitingCardView(concert: concert)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("БЛИЖАЙШИЙ КОНЦЕРТ")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(concert.artist)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Color.white)
                Text("\(concert.city) · \(concert.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.85))
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(days)")
                        .font(.system(size: 64, weight: .heavy))
                    Text("\(daysWord(days)) до концерта")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(Color.white)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.btsPink, Color.btsViolet],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.btsLime)
            Text("Пока ничего не ждёшь")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.white)
            Text("Добавь концерт, на который идёшь, и мы посчитаем дни до него")
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button {
                showForm = true
            } label: {
                Text("Добавить ожидание")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.btsPink, Color.btsViolet],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let first = upcoming.first {
                    heroCard(first)
                }
                if upcoming.count > 1 {
                    Text("ВСЕ ОЖИДАНИЯ · \(upcoming.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(.top, 4)
                    LazyVStack(spacing: 12) {
                        ForEach(upcoming.dropFirst()) { concert in
                            NavigationLink {
                                WaitingCardView(concert: concert)
                            } label: {
                                ConcertRowView(concert: concert)
                                    .concertCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if upcoming.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Ждём")
            .background(Color.btsBackground.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                if !upcoming.isEmpty {
                    Button {
                        showForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                LinearGradient(
                                    colors: [Color.btsPink, Color.btsViolet],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.btsPink.opacity(0.5), radius: 12)
                    }
                    .padding()
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showForm) {
            NewWaitingView()
        }
    }
}

#Preview {
    WaitingScreen()
        .environment(ConcertStore())
}
