import Foundation

// Выбирает форму слова для числа: 1 день, 2 дня, 5 дней
func plural(_ n: Int, one: String, few: String, many: String) -> String {
    let lastTwo = abs(n) % 100
    let last = abs(n) % 10
    if lastTwo >= 11 && lastTwo <= 14 {
        return many
    }
    if last == 1 {
        return one
    }
    if last >= 2 && last <= 4 {
        return few
    }
    return many
}

func daysWord(_ n: Int) -> String {
    plural(n, one: "день", few: "дня", many: "дней")
}

func hoursWord(_ n: Int) -> String {
    plural(n, one: "час", few: "часа", many: "часов")
}

func minutesWord(_ n: Int) -> String {
    plural(n, one: "минута", few: "минуты", many: "минут")
}
