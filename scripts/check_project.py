"""Portable checks for configuration and CI helpers; does not compile Swift."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

import yaml

ROOT = Path(__file__).resolve().parents[1]
TRANSLATED_LANGUAGES = ["vi", "zh-Hans", "ru", "fr", "de"]
# Swift files whose string literals are data, not UI text.
UNSCANNED_FILES = {"SampleLibrary.swift", "SubjectKeywords.swift"}
# SwiftUI calls that localize a bare string-literal argument without help.
AUTO_LOCALIZING = ("Text(", "Label(", "Button(", "Tab(", "Picker(", "TextField(", "Toggle(",
                   "navigationTitle(", "alert(", "confirmationDialog(", "ContentUnavailableView(",
                   "LabeledContent(", "Menu(", "ShareLink(", "Link(", "accessibilityLabel(",
                   "accessibilityHint(", "prompt:")
# Interpolated literals cannot be derived mechanically, so map each to its catalog format key.
INTERPOLATED_KEYS = {
    r"\(lesson.subject.title) · \(lesson.flashcards.count) cards": "%@ · %lld cards",
    r"\(lesson.subject.title) · Awaiting study pack": "%@ · Awaiting study pack",
    r"\(store.lessons.filter { $0.subject == item }.count) lessons": "%lld lessons",
    r"\(filtered.count) found": "%lld found",
    r"\(store.dueCount) cards due": "%lld cards due",
    r"\(store.dueCount) cards waiting\nfor your review": "%lld cards waiting\nfor your review",
    r"\(lesson.dueCards.count) cards due · \(lesson.flashcards.count) total": "%lld cards due · %lld total",
    r"\(lesson.questions.count) questions · With explanations": "%lld questions · With explanations",
    r"\(content.count) characters": "%lld characters",
    r"Couldn't read the text on page \(index + 1). Retake the photo sharper, well lit and straight.": "Couldn't read the text on page %lld. Retake the photo sharper, well lit and straight.",
    r"[Page \(index + 1)]\n\(text)": "[Page %lld]\n%@",
    r"[Page \(index + 1)]\n\(pageText)": "[Page %lld]\n%@",
    r"Couldn't open page \(index + 1).": "Couldn't open page %lld.",
    r"Subject: \(lesson.subject.title). Lesson: \(lesson.title).": "Subject: %@. Lesson: %@.",
    r"Couldn't open the library. The original data is kept. \(error.localizedDescription)": "Couldn't open the library. The original data is kept. %@",
    r"The lesson is stored in the \(lesson.subject.title) folder. Automatic ChatGPT connection isn't in this version; you can take the prompt to ChatGPT and import the result back.": "The lesson is stored in the %@ folder. Automatic ChatGPT connection isn't in this version; you can take the prompt to ChatGPT and import the result back.",
    r"Photo library · \(data.count) pages": "Photo library · %lld pages",
    r"Suggested from the content: \(suggestion.title). You can change the subject above.": "Suggested from the content: %@. You can change the subject above.",
    r"Create 3–8 key points, 5–12 flashcards and 5–10 multiple-choice questions depending on the material. Each question has exactly one correct answer. correctIndex counts from 0. Keep the JSON keys exactly as in the template. Escape special characters according to the JSON standard. \(outputLanguage)": "Create 3–8 key points, 5–12 flashcards and 5–10 multiple-choice questions depending on the material. Each question has exactly one correct answer. correctIndex counts from 0. Keep the JSON keys exactly as in the template. Escape special characters according to the JSON standard. %@",
    r"Progress saved for \(queue.count) cards. Forgotten ones return later today.": "Progress saved for %lld cards. Forgotten ones return later today.",
    r"\(card.intervalDays) days": "%lld days",
    r"\(Int(seconds / 60)) min": "%lld min",
    r"\(Int(seconds / 3_600)) h": "%lld h",
    r"\(Int(seconds / 86_400)) days": "%lld days",
    r"OpenAI refused the sign-in: \(reason).": "OpenAI refused the sign-in: %@.",
    r"Exchanging the access code failed: \(reason).": "Exchanging the access code failed: %@.",
    r"The session is invalid (\(reason)); sign in again.": "The session is invalid (%@); sign in again.",
    r"The ChatGPT request failed: \(reason).": "The ChatGPT request failed: %@.",
    r"Secure storage error (\(Int(status))).": "Secure storage error (%lld).",
    r"\(store.lessons.filter { $0.subject.id == item.id }.count) lessons": "%lld lessons",
    r"\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)": "%@ · iOS %@",
    r"Thinking model: \(thinking).": "Thinking model: %@.",
    r"Standard model: \(standard).": "Standard model: %@.",
    r"\(Int($0.accuracy * 100))%% \(String($0.subject))": "%lld%% %@",
    r"Figures: \(progress.reviewsCompleted) card reviews, \(progress.quizAttempts) quizzes with \(progress.quizCorrect) correct answers, \(progress.lessonsAdded) new lessons, \(progress.cardsDue) cards due out of \(progress.cardsTotal) total.": "Figures: %lld card reviews, %lld quizzes with %lld correct answers, %lld new lessons, %lld cards due out of %lld total.",
    r"Weakest results by subject: \(weakest).": "Weakest results by subject: %@.",
}
# Interpolated literals whose result is pure numbers or protocol plumbing; localization would not change them.
UNLOCALIZED_INTERPOLATIONS = {
    r"\(index + 1)/\(questions.count)", r"\(index + 1) / \(queue.count)",
    r"\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value)",
    r"HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)", r"HTTP \(http.statusCode)",
    r"Bearer \(session.accessToken)",
    r"http://127.0.0.1:\(port)\(Self.path)",
    r"HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n",
    r"issuer \(describeClaim(claims[",
    r"audience \(describeClaim(claims[",
    r"expired \(describeClaim(claims[",
}
# Short ASCII words without spaces that are still user-facing and localized.
LOCALIZED_ASCII_WORDS = {"Done"}
# Literal strings intentionally shown untranslated (language names, OAuth scopes).
UNTRANSLATED_LITERALS = {"Tiếng Việt", "中文", "Русский", "Français", "Deutsch",
                         "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct",
                         "unparseable token", "missing subject", "nonce mismatch", "English", "flashcards"}
# Regex artifacts from adjacent string literals in Swift call arguments, e.g. `, symbolName: `.
CODE_SEPARATOR = re.compile(r'^,? ?[A-Za-z_][A-Za-z0-9_]*: ?$')
PLACEHOLDER = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|L)?[@dDiuUxXoOfeEgGaAcCsSpP]")
LITERAL = re.compile(r'"((?:[^"\\]|\\.)+)"')
SWIFT_ESCAPES = {"\\n": "\n", "\\t": "\t", '\\"': '"', "\\\\": "\\", "\\'": "'"}


def swift_unescape(literal):
    for escaped, actual in SWIFT_ESCAPES.items():
        literal = literal.replace(escaped, actual)
    return literal


def check_string_catalog():
    catalog = json.loads((ROOT / "Scan4Learn/Localizable.xcstrings").read_text(encoding="utf-8"))
    assert catalog["sourceLanguage"] == "en", "English must stay the source language"
    problems = []
    for key, entry in catalog["strings"].items():
        localizations = entry.get("localizations", {})
        missing = [language for language in TRANSLATED_LANGUAGES if language not in localizations]
        if missing:
            problems.append(f"{key!r}: missing translations {missing}")
            continue
        expected = sorted(PLACEHOLDER.findall(key))
        for language in TRANSLATED_LANGUAGES:
            value = localizations[language]["stringUnit"]["value"]
            if not value.strip():
                problems.append(f"{key!r} [{language}]: empty translation")
            found = sorted(PLACEHOLDER.findall(value))
            if found != expected:
                problems.append(f"{key!r} [{language}]: placeholders {found} != key {expected}")
    assert not problems, "\n".join(problems)
    return catalog


def scan_swift_literals(catalog):
    keys = set(catalog["strings"])
    used = set()
    problems = []
    sources = [ROOT / "Scan4Learn/Scan4LearnApp.swift"]
    sources += sorted((ROOT / "Scan4Learn/Views").glob("*.swift"))
    sources += [ROOT / "Scan4Learn/Models/StudyModels.swift", ROOT / "Scan4Learn/Models/StudyStore.swift"]
    sources += sorted((ROOT / "Scan4Learn/Services").glob("*.swift"))
    for path in sources:
        if path.name in UNSCANNED_FILES:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for literal in LITERAL.findall(line):
                has_letters = any(character.isalpha() for character in literal)
                ignorable = not has_letters or len(literal) < 2 or (" " not in literal and literal.isascii())
                if CODE_SEPARATOR.match(literal):
                    continue  # adjacent-literal artifacts between Swift arguments
                if literal in UNTRANSLATED_LITERALS:
                    # Language names and protocol strings stay raw; those that
                    # double as catalog keys still count as used.
                    if literal in keys:
                        used.add(literal)
                    continue
                if ignorable and literal not in keys:
                    continue  # SF symbols, storage keys, numbers, fold helpers…
                if r"\(" in literal:
                    if literal in UNLOCALIZED_INTERPOLATIONS:
                        continue
                    if literal not in INTERPOLATED_KEYS:
                        problems.append(f"{path.name}:{number}: unmapped interpolated literal {literal!r}")
                    else:
                        used.add(INTERPOLATED_KEYS[literal])
                    continue
                key = swift_unescape(literal)
                if key not in keys:
                    problems.append(f"{path.name}:{number}: {literal!r} is missing from the string catalog")
                    continue
                if "String(localized:" not in line and not any(token in line for token in AUTO_LOCALIZING):
                    problems.append(f"{path.name}:{number}: {literal!r} must be wrapped in String(localized:) or a SwiftUI text call")
                used.add(key)
    for pattern, key in INTERPOLATED_KEYS.items():
        if key not in keys:
            problems.append(f"catalog is missing format key {key!r}")
        used.add(key)
    assert not problems, "\n".join(sorted(problems))
    unused = keys - used
    assert not unused, f"Unused catalog entries: {sorted(unused)}"


def run_helper(name, *args, env=None):
    return subprocess.run([sys.executable, str(ROOT / "scripts" / name), *map(str, args)],
                          capture_output=True, text=True, env=env)


def main():
    config = yaml.safe_load((ROOT / "project.yml").read_text(encoding="utf-8"))
    assert config["options"]["deploymentTarget"]["iOS"] == "27.0"
    assert config["options"]["developmentLanguage"] == "en"
    for target in config["targets"].values():
        for source in target["sources"]:
            assert (ROOT / source).exists(), source

    bash = shutil.which("bash")
    if os.name == "nt":
        git_bash = Path("C:/Program Files/Git/bin/bash.exe")
        bash = str(git_bash) if git_bash.exists() else None
    if bash:
        probe = subprocess.run([bash, "--version"], capture_output=True)
        if probe.returncode != 0:
            print(f"SKIP shell syntax: Bash could not start (exit {probe.returncode}).")
            bash = None
    workflows = list((ROOT / ".github/workflows").glob("*.yml"))
    for workflow in workflows:
        # BaseLoader retains 'on' as a string instead of YAML 1.1's boolean.
        document = yaml.load(workflow.read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
        assert "on" in document and "jobs" in document
        for job in document["jobs"].values():
            for step in job["steps"]:
                if "run" in step and bash:
                    check = subprocess.run([bash, "-n"], input=step["run"], text=True, capture_output=True)
                    assert check.returncode == 0, (step.get("name"), check.stderr)

    catalog = check_string_catalog()
    scan_swift_literals(catalog)

    scratch = (ROOT / "build").resolve()
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="scan4learn-check-", dir=scratch) as temp:
        assert Path(temp).resolve().is_relative_to(scratch)
        folder = Path(temp)
        devices = folder / "devices.json"
        devices.write_text(json.dumps({"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0": [{"name": "iPhone 16", "udid": "old", "isAvailable": True}],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
                {"name": "iPhone Duo", "udid": "duo", "isAvailable": True},
                {"name": "iPhone 17", "udid": "new", "isAvailable": True},
                {"name": "iPad Pro", "udid": "ipad", "isAvailable": True},
                {"name": "iPhone 18", "udid": "unavailable", "isAvailable": False}]}}))
        selected = run_helper("select_simulator.py", devices)
        assert selected.returncode == 0 and selected.stdout.strip() == "SIMULATOR_ID=new", selected.stderr
        devices.write_text(json.dumps({"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
                {"name": "iPhone 19 Ultra", "udid": "ultra", "isAvailable": True}]}}))
        selected = run_helper("select_simulator.py", devices)
        assert selected.returncode == 0 and selected.stdout.strip() == "SIMULATOR_ID=ultra", selected.stderr
        devices.write_text(json.dumps({"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
                {"name": "iPhone Duo", "udid": "duo", "isAvailable": True},
                {"name": "iPad Pro", "udid": "ipad", "isAvailable": True}]}}))
        assert run_helper("select_simulator.py", devices).returncode != 0
        devices.write_text('{"devices": {}}')
        assert run_helper("select_simulator.py", devices).returncode != 0

    print(f"PASS: project sources, {len(workflows)} workflows, simulator selection.")
    print(f"PASS: string catalog ({len(catalog['strings'])} keys × {len(TRANSLATED_LANGUAGES)} translations).")
    if bash:
        print("PASS: workflow shell syntax.")
    if "--swift-syntax" in sys.argv:
        sys.path.insert(0, str(ROOT / "build/check-deps"))
        import tree_sitter
        import tree_sitter_swift
        parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
        sources = list((ROOT / "Scan4Learn").rglob("*.swift")) + list((ROOT / "Scan4LearnTests").rglob("*.swift"))
        failures = []
        for source in sources:
            tree = parser.parse(source.read_bytes())
            if tree.root_node.has_error:
                nodes = [tree.root_node]
                while nodes:
                    node = nodes.pop()
                    if node.is_error or node.is_missing:
                        failures.append(f"{source.relative_to(ROOT)}:{node.start_point.row + 1}: {node.type}")
                    nodes.extend(node.children)
        assert not failures, "\n".join(failures)
        print(f"PASS: Swift syntax parsing for {len(sources)} files (not SDK type checking).")
    print("Swift compilation and iPhone runtime tests still require Xcode 27 / GitHub Actions.")


if __name__ == "__main__":
    main()
