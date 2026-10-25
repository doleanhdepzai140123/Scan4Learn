import Foundation

enum SampleLibrary {
    static var lessons: [Lesson] { lessons(for: AppLanguage.seedingCode) }

    /// Sample content ships in every supported language; first launch seeds the device language.
    static func lessons(for language: String?) -> [Lesson] {
        switch String(language?.prefix(2) ?? "") {
        case "en": return english
        case "zh": return chinese
        case "ru": return russian
        case "fr": return french
        case "de": return german
        default: return english
        }
    }

    private static var vietnamese: [Lesson] {
        [
            Lesson(title: "Căn bậc hai & căn thức", subject: .math, sourceName: "Bài mẫu · Toán",
                originalText: "Căn bậc hai số học của số a không âm là số x không âm sao cho x² = a. Căn thức √A xác định khi A ≥ 0. Với mọi số thực a, √(a²) = |a|. Với a ≥ 0 và b ≥ 0, √(ab) = √a · √b.",
                summary: ["√a là số không âm có bình phương bằng a; điều kiện a ≥ 0.", "Căn thức √A có nghĩa khi biểu thức A ≥ 0.", "Luôn nhớ: √(a²) = |a|, không phải lúc nào cũng bằng a.", "Với a, b ≥ 0: √(ab) = √a · √b. Ví dụ: √72 = 6√2."],
                flashcards: [
                    Flashcard(front: "Căn thức √A xác định khi nào?", back: "Khi A ≥ 0. Ví dụ √(x − 2) xác định khi x ≥ 2."),
                    Flashcard(front: "√(a²) bằng gì?", back: "Bằng |a|. Nếu a < 0 thì |a| = −a."),
                    Flashcard(front: "Rút gọn √72", back: "√72 = √(36 × 2) = 6√2."),
                    Flashcard(front: "Căn bậc hai số học của 25 là gì?", back: "Là 5. Số 25 có hai căn bậc hai là 5 và −5, nhưng căn bậc hai số học là số không âm.")
                ], questions: [
                    PracticeQuestion(prompt: "√(x − 3) xác định khi nào?", options: ["x ≥ 3", "x > 3", "x ≤ 3", "Mọi x"], correctIndex: 0, explanation: "Biểu thức dưới dấu căn phải không âm: x − 3 ≥ 0, suy ra x ≥ 3."),
                    PracticeQuestion(prompt: "Giá trị của √((−5)²) là bao nhiêu?", options: ["−5", "25", "5", "±5"], correctIndex: 2, explanation: "√(a²) = |a| nên √((−5)²) = |−5| = 5."),
                    PracticeQuestion(prompt: "√50 được rút gọn thành gì?", options: ["25√2", "5√2", "2√5", "10√5"], correctIndex: 1, explanation: "50 = 25 × 2, nên √50 = √25 × √2 = 5√2.")
                ], isSample: true),
            Lesson(title: "Định luật Ohm", subject: .science, sourceName: "Bài mẫu · KHTN",
                originalText: "Cường độ dòng điện qua điện trở tỉ lệ thuận với hiệu điện thế giữa hai đầu điện trở và tỉ lệ nghịch với điện trở: I = U/R. I đo bằng ampere (A), U đo bằng volt (V), R đo bằng ohm (Ω).",
                summary: ["Định luật Ohm: I = U/R, với R > 0.", "Đơn vị: I (A), U (V), R (Ω). Đổi mA sang A trước khi tính.", "Giữ nguyên R: U tăng bao nhiêu lần thì I tăng bấy nhiêu lần."],
                flashcards: [
                    Flashcard(front: "Công thức định luật Ohm?", back: "I = U/R. I: cường độ dòng điện (A); U: hiệu điện thế (V); R: điện trở (Ω)."),
                    Flashcard(front: "Đổi 250 mA sang A", back: "250 mA = 0,25 A vì 1 A = 1.000 mA.")
                ], questions: [PracticeQuestion(prompt: "U = 12 V, R = 6 Ω. I bằng bao nhiêu?", options: ["72 A", "0,5 A", "2 A", "18 A"], correctIndex: 2, explanation: "I = U/R = 12/6 = 2 A.")], isSample: true),
            Lesson(title: "Relative clauses", subject: .english, sourceName: "Bài mẫu · Tiếng Anh",
                originalText: "Defining relative clauses give essential information about a noun. Use who for people and which for things. That can replace who or which in many defining relative clauses. Do not use commas around a defining relative clause.",
                summary: ["Mệnh đề quan hệ xác định bổ sung thông tin cần thiết để xác định danh từ.", "Who dùng cho người; which dùng cho vật. That có thể thay thế trong nhiều mệnh đề xác định.", "Không đặt dấu phẩy ngăn mệnh đề quan hệ xác định."],
                flashcards: [
                    Flashcard(front: "Who và which khác nhau thế nào?", back: "Who thay cho người; which thay cho vật. Ví dụ: the girl who sings; the book which I read."),
                    Flashcard(front: "Mệnh đề quan hệ xác định có dùng dấu phẩy không?", back: "Không. Thông tin trong mệnh đề cần thiết để xác định người hoặc vật đang nói đến.")
                ], questions: [PracticeQuestion(prompt: "The girl ___ lives next door is my friend.", options: ["which", "who", "where", "when"], correctIndex: 1, explanation: "The girl chỉ người; who làm chủ ngữ của mệnh đề quan hệ.")], isSample: true)
        ]
    }

    private static var english: [Lesson] {
        [
            Lesson(title: "Square roots & radicals", subject: .math, sourceName: "Sample · Math",
                originalText: "The arithmetic square root of a non-negative number a is the non-negative number x such that x² = a. The radical √A is defined when A ≥ 0. For every real number a, √(a²) = |a|. For a ≥ 0 and b ≥ 0, √(ab) = √a · √b.",
                summary: ["√a is the non-negative number whose square equals a; it requires a ≥ 0.", "The radical √A is meaningful only when A ≥ 0.", "Always remember: √(a²) = |a|, which is not always a.", "For a, b ≥ 0: √(ab) = √a · √b. Example: √72 = 6√2."],
                flashcards: [
                    Flashcard(front: "When is the radical √A defined?", back: "When A ≥ 0. Example: √(x − 2) is defined for x ≥ 2."),
                    Flashcard(front: "What is √(a²) equal to?", back: "|a|. If a < 0, then |a| = −a."),
                    Flashcard(front: "Simplify √72", back: "√72 = √(36 × 2) = 6√2."),
                    Flashcard(front: "What is the arithmetic square root of 25?", back: "5. The number 25 has two square roots, 5 and −5, but the arithmetic one is the non-negative value.")
                ], questions: [
                    PracticeQuestion(prompt: "When is √(x − 3) defined?", options: ["x ≥ 3", "x > 3", "x ≤ 3", "Every x"], correctIndex: 0, explanation: "The expression under the root must be non-negative: x − 3 ≥ 0, so x ≥ 3."),
                    PracticeQuestion(prompt: "What is the value of √((−5)²)?", options: ["−5", "25", "5", "±5"], correctIndex: 2, explanation: "√(a²) = |a|, so √((−5)²) = |−5| = 5."),
                    PracticeQuestion(prompt: "What is √50 simplified?", options: ["25√2", "5√2", "2√5", "10√5"], correctIndex: 1, explanation: "50 = 25 × 2, so √50 = √25 × √2 = 5√2.")
                ], isSample: true),
            Lesson(title: "Ohm's law", subject: .science, sourceName: "Sample · Science",
                originalText: "The current through a resistor is proportional to the voltage across it and inversely proportional to the resistance: I = U/R. I is measured in amperes (A), U in volts (V), and R in ohms (Ω).",
                summary: ["Ohm's law: I = U/R, with R > 0.", "Units: I (A), U (V), R (Ω). Convert mA to A before calculating.", "With R constant, if U increases by a factor, I increases by the same factor."],
                flashcards: [
                    Flashcard(front: "The formula of Ohm's law?", back: "I = U/R. I: current (A); U: voltage (V); R: resistance (Ω)."),
                    Flashcard(front: "Convert 250 mA to A", back: "250 mA = 0.25 A because 1 A = 1,000 mA.")
                ], questions: [PracticeQuestion(prompt: "U = 12 V and R = 6 Ω. What is I?", options: ["72 A", "0.5 A", "2 A", "18 A"], correctIndex: 2, explanation: "I = U/R = 12/6 = 2 A.")], isSample: true),
            Lesson(title: "Relative clauses", subject: .english, sourceName: "Sample · English",
                originalText: "Defining relative clauses give essential information about a noun. Use who for people and which for things. That can replace who or which in many defining relative clauses. Do not use commas around a defining relative clause.",
                summary: ["Defining relative clauses add essential information that identifies the noun.", "Who is used for people; which is used for things. That can replace them in many defining clauses.", "Do not put commas around a defining relative clause."],
                flashcards: [
                    Flashcard(front: "How do who and which differ?", back: "Who replaces a person; which replaces a thing. Example: the girl who sings; the book which I read."),
                    Flashcard(front: "Does a defining relative clause use commas?", back: "No. The information is essential to identify the person or thing being described.")
                ], questions: [PracticeQuestion(prompt: "The girl ___ lives next door is my friend.", options: ["which", "who", "where", "when"], correctIndex: 1, explanation: "The girl refers to a person; who is the subject of the relative clause.")], isSample: true)
        ]
    }

    private static var chinese: [Lesson] {
        [
            Lesson(title: "平方根与根式", subject: .math, sourceName: "示例 · 数学",
                originalText: "非负数 a 的算术平方根是满足 x² = a 的非负数 x。当 A ≥ 0 时根式 √A 有意义。对任意实数 a，√(a²) = |a|。当 a ≥ 0 且 b ≥ 0 时，√(ab) = √a · √b。",
                summary: ["√a 是平方等于 a 的非负数，要求 a ≥ 0。", "根式 √A 只在 A ≥ 0 时有意义。", "牢记：√(a²) = |a|，不一定等于 a。", "当 a, b ≥ 0 时：√(ab) = √a · √b。例如 √72 = 6√2。"],
                flashcards: [
                    Flashcard(front: "根式 √A 何时有意义？", back: "当 A ≥ 0 时。例如 √(x − 2) 在 x ≥ 2 时有意义。"),
                    Flashcard(front: "√(a²) 等于什么？", back: "等于 |a|。若 a < 0，则 |a| = −a。"),
                    Flashcard(front: "化简 √72", back: "√72 = √(36 × 2) = 6√2。"),
                    Flashcard(front: "25 的算术平方根是多少？", back: "是 5。25 有两个平方根 5 和 −5，但算术平方根取非负值。")
                ], questions: [
                    PracticeQuestion(prompt: "√(x − 3) 何时有意义？", options: ["x ≥ 3", "x > 3", "x ≤ 3", "任意 x"], correctIndex: 0, explanation: "根号下的式子必须非负：x − 3 ≥ 0，所以 x ≥ 3。"),
                    PracticeQuestion(prompt: "√((−5)²) 的值是多少？", options: ["−5", "25", "5", "±5"], correctIndex: 2, explanation: "√(a²) = |a|，所以 √((−5)²) = |−5| = 5。"),
                    PracticeQuestion(prompt: "√50 可化简为什么？", options: ["25√2", "5√2", "2√5", "10√5"], correctIndex: 1, explanation: "50 = 25 × 2，所以 √50 = √25 × √2 = 5√2。")
                ], isSample: true),
            Lesson(title: "欧姆定律", subject: .science, sourceName: "示例 · 科学",
                originalText: "通过导体的电流与导体两端的电压成正比，与导体的电阻成反比：I = U/R。I 的单位是安培（A），U 的单位是伏特（V），R 的单位是欧姆（Ω）。",
                summary: ["欧姆定律：I = U/R，其中 R > 0。", "单位：I（A）、U（V）、R（Ω）。计算前先把 mA 换算成 A。", "R 不变时，U 增大到原来的几倍，I 也增大到同样的倍数。"],
                flashcards: [
                    Flashcard(front: "欧姆定律的公式是什么？", back: "I = U/R。I：电流（A）；U：电压（V）；R：电阻（Ω）。"),
                    Flashcard(front: "把 250 mA 换算成 A", back: "250 mA = 0.25 A，因为 1 A = 1000 mA。")
                ], questions: [PracticeQuestion(prompt: "U = 12 V，R = 6 Ω，I 是多少？", options: ["72 A", "0.5 A", "2 A", "18 A"], correctIndex: 2, explanation: "I = U/R = 12/6 = 2 A。")], isSample: true),
            Lesson(title: "定语从句", subject: .english, sourceName: "示例 · 英语",
                originalText: "Defining relative clauses give essential information about a noun. Use who for people and which for things. That can replace who or which in many defining relative clauses. Do not use commas around a defining relative clause.",
                summary: ["限定性定语从句提供确定名词所必需的信息。", "who 指人，which 指物；that 在许多限定性从句中可以代替它们。", "限定性定语从句前后不加逗号。"],
                flashcards: [
                    Flashcard(front: "who 和 which 有什么区别？", back: "who 代替人，which 代替物。例如：the girl who sings；the book which I read。"),
                    Flashcard(front: "限定性定语从句要加逗号吗？", back: "不加。从句信息对于确定所说的人或物是必需的。")
                ], questions: [PracticeQuestion(prompt: "The girl ___ lives next door is my friend.", options: ["which", "who", "where", "when"], correctIndex: 1, explanation: "the girl 指人，who 作定语从句的主语。")], isSample: true)
        ]
    }

    private static var russian: [Lesson] {
        [
            Lesson(title: "Квадратные корни", subject: .math, sourceName: "Пример · Математика",
                originalText: "Арифметический квадратный корень из неотрицательного числа a — это неотрицательное число x, такое что x² = a. Корень √A имеет смысл, когда A ≥ 0. Для любого действительного числа a: √(a²) = |a|. При a ≥ 0 и b ≥ 0: √(ab) = √a · √b.",
                summary: ["√a — неотрицательное число, квадрат которого равен a; требуется a ≥ 0.", "Корень √A имеет смысл только при A ≥ 0.", "Всегда помни: √(a²) = |a|, а не всегда a.", "При a, b ≥ 0: √(ab) = √a · √b. Пример: √72 = 6√2."],
                flashcards: [
                    Flashcard(front: "Когда корень √A имеет смысл?", back: "Когда A ≥ 0. Например, √(x − 2) имеет смысл при x ≥ 2."),
                    Flashcard(front: "Чему равен √(a²)?", back: "|a|. Если a < 0, то |a| = −a."),
                    Flashcard(front: "Упрости √72", back: "√72 = √(36 × 2) = 6√2."),
                    Flashcard(front: "Чему равен арифметический квадратный корень из 25?", back: "5. У числа 25 два квадратных корня: 5 и −5, но арифметический — неотрицательный.")
                ], questions: [
                    PracticeQuestion(prompt: "Когда выражение √(x − 3) имеет смысл?", options: ["x ≥ 3", "x > 3", "x ≤ 3", "при любом x"], correctIndex: 0, explanation: "Подкоренное выражение должно быть неотрицательным: x − 3 ≥ 0, значит x ≥ 3."),
                    PracticeQuestion(prompt: "Чему равно √((−5)²)?", options: ["−5", "25", "5", "±5"], correctIndex: 2, explanation: "√(a²) = |a|, поэтому √((−5)²) = |−5| = 5."),
                    PracticeQuestion(prompt: "Упрости √50.", options: ["25√2", "5√2", "2√5", "10√5"], correctIndex: 1, explanation: "50 = 25 × 2, поэтому √50 = √25 × √2 = 5√2.")
                ], isSample: true),
            Lesson(title: "Закон Ома", subject: .science, sourceName: "Пример · Естествознание",
                originalText: "Сила тока через резистор прямо пропорциональна напряжению на его концах и обратно пропорциональна сопротивлению: I = U/R. I измеряется в амперах (А), U — в вольтах (В), R — в омах (Ω).",
                summary: ["Закон Ома: I = U/R, где R > 0.", "Единицы: I (А), U (В), R (Ω). Перед расчётом переведи мА в А.", "При неизменном R: во сколько раз увеличится U, во столько же раз увеличится I."],
                flashcards: [
                    Flashcard(front: "Формула закона Ома?", back: "I = U/R. I — сила тока (А); U — напряжение (В); R — сопротивление (Ω)."),
                    Flashcard(front: "Переведи 250 мА в А", back: "250 мА = 0,25 А, так как 1 А = 1000 мА.")
                ], questions: [PracticeQuestion(prompt: "U = 12 В, R = 6 Ω. Чему равен I?", options: ["72 А", "0,5 А", "2 А", "18 А"], correctIndex: 2, explanation: "I = U/R = 12/6 = 2 А.")], isSample: true),
            Lesson(title: "Определительные придаточные", subject: .english, sourceName: "Пример · Английский",
                originalText: "Defining relative clauses give essential information about a noun. Use who for people and which for things. That can replace who or which in many defining relative clauses. Do not use commas around a defining relative clause.",
                summary: ["Определительные придаточные добавляют существенную информацию о существительном.", "Who — о людях; which — о предметах. That во многих случаях может их заменить.", "Определительное придаточное не выделяется запятыми."],
                flashcards: [
                    Flashcard(front: "Чем отличаются who и which?", back: "Who заменяет человека, which — предмет. Например: the girl who sings; the book which I read."),
                    Flashcard(front: "Нужны ли запятые в определительном придаточном?", back: "Нет. Информация придаточного необходима, чтобы понять, о ком или о чём идёт речь.")
                ], questions: [PracticeQuestion(prompt: "The girl ___ lives next door is my friend.", options: ["which", "who", "where", "when"], correctIndex: 1, explanation: "The girl обозначает человека; who — подлежащее придаточного.")], isSample: true)
        ]
    }

    private static var french: [Lesson] {
        [
            Lesson(title: "Racines carrées", subject: .math, sourceName: "Exemple · Mathématiques",
                originalText: "La racine carrée arithmétique d'un nombre positif ou nul a est le nombre positif ou nul x tel que x² = a. Le radical √A est défini lorsque A ≥ 0. Pour tout réel a, √(a²) = |a|. Pour a ≥ 0 et b ≥ 0, √(ab) = √a · √b.",
                summary: ["√a est le nombre positif ou nul dont le carré vaut a ; il faut a ≥ 0.", "Le radical √A n'a de sens que si A ≥ 0.", "Toujours retenir : √(a²) = |a|, et pas toujours a.", "Pour a, b ≥ 0 : √(ab) = √a · √b. Exemple : √72 = 6√2."],
                flashcards: [
                    Flashcard(front: "Quand le radical √A est-il défini ?", back: "Lorsque A ≥ 0. Exemple : √(x − 2) est défini pour x ≥ 2."),
                    Flashcard(front: "Que vaut √(a²) ?", back: "|a|. Si a < 0, alors |a| = −a."),
                    Flashcard(front: "Simplifie √72", back: "√72 = √(36 × 2) = 6√2."),
                    Flashcard(front: "Quelle est la racine carrée arithmétique de 25 ?", back: "5. Le nombre 25 a deux racines carrées, 5 et −5, mais la racine arithmétique est la valeur positive ou nulle.")
                ], questions: [
                    PracticeQuestion(prompt: "Quand √(x − 3) est-il défini ?", options: ["x ≥ 3", "x > 3", "x ≤ 3", "Pour tout x"], correctIndex: 0, explanation: "L'expression sous la racine doit être positive ou nulle : x − 3 ≥ 0, donc x ≥ 3."),
                    PracticeQuestion(prompt: "Que vaut √((−5)²) ?", options: ["−5", "25", "5", "±5"], correctIndex: 2, explanation: "√(a²) = |a|, donc √((−5)²) = |−5| = 5."),
                    PracticeQuestion(prompt: "Comment simplifier √50 ?", options: ["25√2", "5√2", "2√5", "10√5"], correctIndex: 1, explanation: "50 = 25 × 2, donc √50 = √25 × √2 = 5√2.")
                ], isSample: true),
            Lesson(title: "Loi d'Ohm", subject: .science, sourceName: "Exemple · Sciences",
                originalText: "L'intensité du courant dans un résistor est proportionnelle à la tension à ses bornes et inversement proportionnelle à sa résistance : I = U/R. I s'exprime en ampères (A), U en volts (V) et R en ohms (Ω).",
                summary: ["Loi d'Ohm : I = U/R, avec R > 0.", "Unités : I (A), U (V), R (Ω). Convertis les mA en A avant de calculer.", "À R constant, si U est multipliée par un facteur, I est multipliée par le même facteur."],
                flashcards: [
                    Flashcard(front: "La formule de la loi d'Ohm ?", back: "I = U/R. I : intensité (A) ; U : tension (V) ; R : résistance (Ω)."),
                    Flashcard(front: "Convertis 250 mA en A", back: "250 mA = 0,25 A car 1 A = 1 000 mA.")
                ], questions: [PracticeQuestion(prompt: "U = 12 V et R = 6 Ω. Que vaut I ?", options: ["72 A", "0,5 A", "2 A", "18 A"], correctIndex: 2, explanation: "I = U/R = 12/6 = 2 A.")], isSample: true),
            Lesson(title: "Propositions relatives", subject: .english, sourceName: "Exemple · Anglais",
                originalText: "Defining relative clauses give essential information about a noun. Use who for people and which for things. That can replace who or which in many defining relative clauses. Do not use commas around a defining relative clause.",
                summary: ["Les propositions relatives déterminatives apportent une information essentielle pour identifier le nom.", "Who s'emploie pour les personnes ; which pour les choses. That peut les remplacer dans beaucoup de cas.", "On ne met pas de virgules autour d'une proposition relative déterminative."],
                flashcards: [
                    Flashcard(front: "Quelle différence entre who et which ?", back: "Who remplace une personne ; which remplace une chose. Exemples : the girl who sings ; the book which I read."),
                    Flashcard(front: "Une proposition relative déterminative prend-elle des virgules ?", back: "Non. Son information est indispensable pour identifier la personne ou la chose décrite.")
                ], questions: [PracticeQuestion(prompt: "The girl ___ lives next door is my friend.", options: ["which", "who", "where", "when"], correctIndex: 1, explanation: "The girl désigne une personne ; who est le sujet de la subordonnée relative.")], isSample: true)
        ]
    }

    private static var german: [Lesson] {
        [
            Lesson(title: "Quadratwurzeln", subject: .math, sourceName: "Beispiel · Mathematik",
                originalText: "Die Quadratwurzel einer nichtnegativen Zahl a ist die nichtnegative Zahl x mit x² = a. Die Wurzel √A ist definiert, wenn A ≥ 0. Für jede reelle Zahl a gilt: √(a²) = |a|. Für a ≥ 0 und b ≥ 0 gilt √(ab) = √a · √b.",
                summary: ["√a ist die nichtnegative Zahl, deren Quadrat a ergibt; es gilt a ≥ 0.", "Die Wurzel √A ist nur für A ≥ 0 definiert.", "Merke immer: √(a²) = |a|, nicht immer a.", "Für a, b ≥ 0: √(ab) = √a · √b. Beispiel: √72 = 6√2."],
                flashcards: [
                    Flashcard(front: "Wann ist die Wurzel √A definiert?", back: "Wenn A ≥ 0. Beispiel: √(x − 2) ist definiert für x ≥ 2."),
                    Flashcard(front: "Was ist √(a²)?", back: "Gleich |a|. Wenn a < 0, dann |a| = −a."),
                    Flashcard(front: "Vereinfache √72", back: "√72 = √(36 × 2) = 6√2."),
                    Flashcard(front: "Was ist die Quadratwurzel von 25?", back: "5. Die Zahl 25 hat zwei Quadratwurzeln, 5 und −5, aber die Quadratwurzel ist nichtnegativ.")
                ], questions: [
                    PracticeQuestion(prompt: "Wann ist √(x − 3) definiert?", options: ["x ≥ 3", "x > 3", "x ≤ 3", "für alle x"], correctIndex: 0, explanation: "Der Term unter der Wurzel muss nichtnegativ sein: x − 3 ≥ 0, also x ≥ 3."),
                    PracticeQuestion(prompt: "Was ist √((−5)²)?", options: ["−5", "25", "5", "±5"], correctIndex: 2, explanation: "√(a²) = |a|, also √((−5)²) = |−5| = 5."),
                    PracticeQuestion(prompt: "Wie vereinfacht man √50?", options: ["25√2", "5√2", "2√5", "10√5"], correctIndex: 1, explanation: "50 = 25 × 2, also √50 = √25 × √2 = 5√2.")
                ], isSample: true),
            Lesson(title: "Ohmsches Gesetz", subject: .science, sourceName: "Beispiel · Naturwissenschaft",
                originalText: "Die Stromstärke durch einen Widerstand ist proportional zur Spannung an seinen Enden und umgekehrt proportional zum Widerstand: I = U/R. I wird in Ampere (A) gemessen, U in Volt (V) und R in Ohm (Ω).",
                summary: ["Ohmsches Gesetz: I = U/R, mit R > 0.", "Einheiten: I (A), U (V), R (Ω). Rechne mA in A um, bevor du rechnest.", "Bleibt R gleich, wächst I um denselben Faktor wie U."],
                flashcards: [
                    Flashcard(front: "Die Formel des ohmschen Gesetzes?", back: "I = U/R. I: Stromstärke (A); U: Spannung (V); R: Widerstand (Ω)."),
                    Flashcard(front: "Rechne 250 mA in A um", back: "250 mA = 0,25 A, denn 1 A = 1.000 mA.")
                ], questions: [PracticeQuestion(prompt: "U = 12 V und R = 6 Ω. Wie groß ist I?", options: ["72 A", "0,5 A", "2 A", "18 A"], correctIndex: 2, explanation: "I = U/R = 12/6 = 2 A.")], isSample: true),
            Lesson(title: "Relativsätze", subject: .english, sourceName: "Beispiel · Englisch",
                originalText: "Defining relative clauses give essential information about a noun. Use who for people and which for things. That can replace who or which in many defining relative clauses. Do not use commas around a defining relative clause.",
                summary: ["Bestimmende Relativsätze liefern wesentliche Informationen zu einem Nomen.", "Who steht für Personen, which für Dinge. That kann in vielen bestimmenden Relativsätzen beides ersetzen.", "Bestimmende Relativsätze werden nicht durch Kommas abgetrennt."],
                flashcards: [
                    Flashcard(front: "Was ist der Unterschied zwischen who und which?", back: "Who steht für Personen, which für Dinge. Beispiele: the girl who sings; the book which I read."),
                    Flashcard(front: "Braucht ein bestimmender Relativsatz Kommas?", back: "Nein. Die Information ist nötig, um die Person oder Sache eindeutig zu bestimmen.")
                ], questions: [PracticeQuestion(prompt: "The girl ___ lives next door is my friend.", options: ["which", "who", "where", "when"], correctIndex: 1, explanation: "The girl bezeichnet eine Person; who ist das Subjekt des Relativsatzes.")], isSample: true)
        ]
    }
}
