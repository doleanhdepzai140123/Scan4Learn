import UIKit

/// A curated set of SF Symbols that make sense as subject folder icons.
/// `available` filters out anything the running OS cannot render, so the
/// picker never shows blank tiles on older symbol sets.
enum SubjectIconCatalog {
    static let symbols: [String] = [
        // Math & numbers
        "function", "numbers", "x.squareroot", "equal", "plus.forwardslash.minus", "percent",
        "sum", "divide", "infinity", "ruler", "compass.drawing", "scalemass",
        // Language & literature
        "book", "book.closed", "text.book.closed", "books.vertical", "pencil", "textformat",
        "abc", "character.bubble", "text.quote", "signature", "translate", "globe", "quote.opening",
        // Science
        "atom", "flask", "testtube.2", "dna", "leaf", "drop", "scope",
        "thermometer.medium", "stethoscope", "cross.case", "syringe", "pills",
        // Geography & weather
        "globe.americas", "globe.asia.australia", "globe.europe.africa", "map", "gauge",
        "sun.max", "moon.stars", "cloud", "snowflake", "wind", "tornado",
        // Time
        "clock", "hourglass", "calendar", "timer", "alarm",
        // People & health
        "person.2", "person.crop.circle", "heart", "brain", "eyeglasses", "hand.raised",
        "figure.run", "figure.walk",
        // Arts & music
        "music.note", "music.quarternote.3", "pianokeys", "theatermasks", "paintpalette",
        "paintbrush", "camera", "film", "waveform", "mic", "headphones", "guitars",
        // Sports
        "soccerball", "basketball", "tennis.racquet", "tabletennis", "gamecontroller",
        "dumbbell", "bicycle", "flag.checkered", "trophy",
        // Places & transport
        "airplane", "car", "building.2", "house", "building.columns", "signpost.right",
        // Money & business
        "banknote", "cart", "storefront", "chart.bar", "chart.line.uptrend.xyaxis", "briefcase",
        // Technology
        "wrench.and.screwdriver", "hammer", "cpu", "memorychip", "network",
        "antenna.radiowaves.left.and.right", "battery", "bolt", "keyboard", "desktopcomputer", "tv",
        // Learning & misc
        "flame", "lightbulb", "sparkles", "target", "questionmark.circle", "graduationcap",
        "studentdesk", "paperplane", "flag", "star", "eye", "ear", "square.stack.3d.up",
        "cube", "shippingbox", "scissors", "paperclip", "folder", "archivebox", "bookmark",
        "tag", "magnifyingglass", "iphone"
    ]

    /// Symbols the current OS can actually render.
    static var available: [String] {
        symbols.filter { UIImage(systemName: $0) != nil }
    }
}
