# Second device table report (orientation up, cleaner OCR). Exercises:
#  - a single entry wrapped on BOTH sides: "Wszystko"/"w porządku." <-> "Everything's"/"fine."
#  - a 3-line Polish cell: "rozwiedziony"/"(m.),"/"rozwiedziona (f.)" <-> "divorced"
#  - gendered entry wrapped on both sides: "przyjaciel (m.),"/"przyjaciółka (f.)" <-> "close/dear"/"friend"
# Per-line language tags are the real device tags (mirror's pair.lang is only a stub).
from mirror import analyze, S

# (text, x, y, h, lang)
raw = [
    ("fiancé", 0.853, 0.049, 0.056, "en"), ("narzeczony", 0.690, 0.067, 0.053, "pl"),
    ("imię", 0.009, 0.071, 0.061, "pl"), ("(first) name", 0.183, 0.082, 0.061, "en"),
    ("address", 0.523, 0.084, 0.049, "en"), ("adres", 0.363, 0.086, 0.050, "pl"),
    ("fiancée", 0.853, 0.139, 0.056, "en"), ("narzeczona", 0.691, 0.159, 0.052, "pl"),
    ("phone number", 0.526, 0.173, 0.058, "en"), ("surname, last", 0.185, 0.175, 0.063, "en"),
    ("numer telefonu", 0.365, 0.176, 0.057, "pl"), ("nazwisko", 0.012, 0.188, 0.053, "pl"),
    ("to be in", 0.851, 0.226, 0.055, "en"), ("name", 0.186, 0.235, 0.038, "en"),
    ("e-mail address", 0.524, 0.258, 0.058, "en"), ("(adres) e-mail", 0.363, 0.261, 0.058, "pl"),
    ("być w związku", 0.692, 0.273, 0.068, "pl"), ("a relationship", 0.853, 0.297, 0.065, "en"),
    ("My name/", 0.187, 0.314, 0.062, "en"), ("Nazywam się...", 0.015, 0.339, 0.066, "pl"),
    ("wolny (m.),", 0.365, 0.347, 0.067, "pl"), ("surname is...", 0.186, 0.372, 0.057, "en"),
    ("single", 0.524, 0.374, 0.059, "en"), ("birthday", 0.853, 0.379, 0.063, "en"),
    ("urodziny", 0.691, 0.389, 0.069, "pl"), ("wolna (f.)", 0.365, 0.408, 0.058, "pl"),
    ("nazwisko", 0.016, 0.445, 0.053, "pl"), ("hometown", 0.853, 0.472, 0.050, "en"),
    ("rodzinne miasto", 0.691, 0.474, 0.066, "pl"), ("maiden name", 0.188, 0.484, 0.045, "en"),
    ("żonaty (m.),", 0.363, 0.488, 0.062, "pl"), ("married", 0.527, 0.514, 0.047, "en"),
    ("panieńskie", 0.017, 0.515, 0.060, "pl"), ("zamężna (f.)", 0.365, 0.551, 0.069, "pl"),
    ("to know (e.g. to", 0.851, 0.555, 0.064, "en"), ("znać", 0.690, 0.591, 0.058, "pl"),
    ("kolega (m.),", 0.017, 0.597, 0.068, "pl"), ("know sb)", 0.852, 0.620, 0.059, "en"),
    ("friend", 0.186, 0.622, 0.053, "en"), ("rozwiedziony", 0.365, 0.623, 0.061, "pl"),
    ("koleżanka (f.)", 0.017, 0.655, 0.070, "pl"), ("divorced", 0.526, 0.680, 0.056, "en"),
    ("(m.),", 0.363, 0.696, 0.061, "?"), ("What's up?", 0.852, 0.704, 0.062, "en"),
    ("Co słychać?", 0.693, 0.706, 0.067, "pl"), ("close/dear", 0.189, 0.737, 0.045, "en"),
    ("przyjaciel (m.),", 0.019, 0.739, 0.066, "pl"), ("rozwiedziona (f.)", 0.365, 0.751, 0.058, "pl"),
    ("Everything's", 0.852, 0.788, 0.072, "en"), ("Wszystko", 0.693, 0.790, 0.062, "pl"),
    ("friend", 0.189, 0.800, 0.050, "en"), ("przyjaciółka (f.)", 0.019, 0.804, 0.070, "pl"),
    ("husband", 0.526, 0.829, 0.051, "en"), ("mąż", 0.365, 0.839, 0.061, "pl"),
    ("w porządku.", 0.693, 0.855, 0.066, "pl"), ("fine.", 0.850, 0.857, 0.063, "en"),
    ("to be ... years", 0.189, 0.882, 0.056, "en"), ("wife", 0.528, 0.912, 0.053, "en"),
    ("mieć ... lat/lata", 0.022, 0.914, 0.065, "pl"), ("żona", 0.365, 0.920, 0.053, "pl"),
    ("chłopak", 0.693, 0.936, 0.066, "pl"), ("boyfriend", 0.852, 0.937, 0.065, "en"),
    ("old", 0.190, 0.941, 0.053, "en"),
]
edges = [0.16, 0.34, 0.50, 0.66, 0.82, 0.99]
T = []
for text, x, y, h, lang in raw:
    right = next((e for e in edges if e > x + 0.005), 0.99)
    s = S(text, x, y, max(right - x, 0.02), h)
    s["lang"] = lang
    T.append(s)

R = analyze(T, mode="table")
print("pairs:", len(R["table"]))
for t in R["table"]:
    print("  ", t)
print("leftovers:", R["left"])
