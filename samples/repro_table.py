# Device table report: 3 blocks side by side; several Polish cells span two lines
# (gendered forms like "wolny (m.), / wolna (f.)") sharing one English word.
# Regression fixture for symmetric (multi-line-on-either-side) cell pairing.
# Per-line language tags are the real device tags (mirror's pair.lang is only a stub).
from mirror import analyze, S

# (text, x, y, h, lang)
raw = [
    ("imię", 0.020, 0.079, 0.058, "pl"), ("(tirst) name", 0.186, 0.092, 0.052, "en"),
    ("fiancé", 0.827, 0.100, 0.054, "en"), ("adres", 0.362, 0.104, 0.048, "pl"), ("address", 0.516, 0.112, 0.049, "en"),
    ("narzeczony", 0.676, 0.119, 0.046, "pl"),
    ("surname, last", 0.187, 0.180, 0.064, "en"), ("fiancée", 0.827, 0.184, 0.056, "en"), ("nazwisko", 0.021, 0.188, 0.057, "pl"),
    ("numer telefonu", 0.361, 0.189, 0.058, "pl"), ("phone number", 0.516, 0.194, 0.063, "en"), ("narzeczona", 0.677, 0.196, 0.046, "pl"),
    ("name", 0.189, 0.235, 0.039, "en"), ("to be in", 0.828, 0.260, 0.048, "en"), ("(adres) e-mail", 0.360, 0.270, 0.064, "pl"),
    ("e-mail address", 0.517, 0.275, 0.042, "en"), ("być w związku", 0.677, 0.298, 0.067, "pl"),
    ("My name/", 0.189, 0.310, 0.058, "en"), ("a relationship", 0.830, 0.325, 0.060, "en"), ("Nazywam się...", 0.021, 0.335, 0.073, "pl"),
    ("wolny (m.),", 0.362, 0.350, 0.068, "pl"), ("surname is...", 0.187, 0.370, 0.070, "en"), ("single", 0.517, 0.385, 0.054, "en"),
    ("birthday", 0.829, 0.398, 0.075, "en"), ("wolna (f.)", 0.362, 0.406, 0.055, "pl"), ("urodziny", 0.678, 0.408, 0.063, "pl"),
    ("nazwisko", 0.022, 0.435, 0.055, "pl"), ("maiden name", 0.189, 0.475, 0.050, "en"), ("żonaty (m.),", 0.361, 0.483, 0.060, "pl"),
    ("rodzinne miasto", 0.679, 0.486, 0.046, "pl"), ("hometown", 0.831, 0.487, 0.054, "en"), ("panieńskie", 0.021, 0.504, 0.060, "pl"),
    ("married", 0.520, 0.512, 0.042, "en"), ("zamężna (f.)", 0.362, 0.542, 0.060, "pl"), ("to know (e.g. to", 0.831, 0.564, 0.060, "en"),
    ("kolega (m.),", 0.021, 0.585, 0.068, "pl"), ("znać", 0.679, 0.594, 0.046, "pl"), ("friend", 0.187, 0.610, 0.055, "en"),
    (",rozwiedziony", 0.360, 0.615, 0.062, "pl"), ("know sb)", 0.833, 0.625, 0.051, "en"), ("koleżanka (f.)", 0.022, 0.646, 0.059, "pl"),
    ("divorced", 0.519, 0.677, 0.047, "en"), ("(m.),", 0.360, 0.685, 0.062, "?"), ("Co słychae?", 0.679, 0.703, 0.063, "pl"),
    ("What's up?", 0.833, 0.706, 0.063, "en"), ("close/dear", 0.189, 0.723, 0.046, "en"), ("przyjaciel (m.),", 0.020, 0.724, 0.077, "pl"),
    ("rozwiedziona (f)", 0.360, 0.740, 0.064, "pl"), ("Wszystke", 0.680, 0.779, 0.054, "pl"), ("Everything's", 0.836, 0.779, 0.067, "en"),
    ("friend", 0.187, 0.785, 0.046, "en"), ("przyjaciółka (f.)", 0.020, 0.788, 0.070, "pl"), ("husband", 0.520, 0.815, 0.048, "en"),
    ("maza eroto pin", 0.358, 0.817, 0.090, "pl"), ("fine.", 0.834, 0.842, 0.058, "en"), ("to be... years", 0.187, 0.867, 0.054, "en"),
    ("wife", 0.520, 0.894, 0.054, "en"), ("mieć ... lat/lata", 0.022, 0.898, 0.062, "pl"), ("żona", 0.363, 0.902, 0.054, "pl"),
    ("old", 0.189, 0.923, 0.054, "en"), ("beyfriend", 0.833, 0.929, 0.069, "en"),
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
