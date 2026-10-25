/// Diacritic-folded keyword hints per subject, covering every supported app language.
/// Cyrillic and Han characters pass through diacritic folding unchanged.
/// Used only for the local folder suggestion; the student always confirms the folder.
struct SubjectKeywordEntry {
    let id: String
    let keywords: [String]
}

enum SubjectKeywords {
    static let all: [SubjectKeywordEntry] = [
        SubjectKeywordEntry(id: "math", keywords: [
            "phuong trinh", "can bac hai", "tam giac", "ham so", "duong tron", "he thuc",
            "equation", "square root", "triangle", "theorem", "function",
            "gleichung", "dreieck", "funktion", "pythagoras",
            "theoreme", "fonction",
            "уравнение", "треугольник", "функция", "теорема",
            "方程", "三角形", "函数", "定理"
        ]),
        SubjectKeywordEntry(id: "literature", keywords: [
            "nha tho", "nhan vat", "tac pham", "nghi luan", "an du", "van ban",
            "poem", "poetry", "novel", "character",
            "gedicht", "roman", "figur", "literatur",
            "poeme", "personnage", "vers", "recit",
            "стихотворение", "поэма", "герой", "роман",
            "诗歌", "小说", "人物", "散文"
        ]),
        SubjectKeywordEntry(id: "english", keywords: [
            "present perfect", "past simple", "vocabulary", "grammar", "relative clause"
        ]),
        SubjectKeywordEntry(id: "science", keywords: [
            "dien tro", "dinh luat ohm", "nhiem sac the", "phan ung", "hoa hoc", "dong dien",
            "resistance", "ohm's law", "current", "voltage", "chromosome",
            "widerstand", "ohmsche", "reaktion", "chemie", "stromkreis",
            "loi d'ohm", "reaction", "chimie", "electricite",
            "сопротивление", "закон ома", "реакция", "химия", "хромосома",
            "电阻", "欧姆定律", "化学", "电流", "染色体"
        ]),
        SubjectKeywordEntry(id: "historyGeography", keywords: [
            "chien tranh", "cach mang", "dia li", "dan so", "khi hau", "lich su",
            "war", "revolution", "climate", "population", "geography",
            "krieg", "klima", "bevolkerung", "geschichte",
            "guerre", "geographie", "climat",
            "война", "революция", "климат", "население", "география",
            "战争", "革命", "气候", "人口", "地理"
        ])
    ]
}
