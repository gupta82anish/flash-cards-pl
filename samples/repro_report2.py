# Second device report: a numbered exercise page covering items 16–36
# (numbering does NOT start at 1). Regression fixture for the min..max fix.
from mirror import analyze, S

raw = [
    ("We remember it very well.", 0.057, 0.026, 0.034),
    ("16. Pamiętamy to bardzo dobrze.", 0.705, 0.032, 0.021),
    ("16.", 0.033, 0.033, 0.019),
    ("What are you doing here?", 0.065, 0.073, 0.033),
    ("17. Co ty tutaj/tu robisz?", 0.708, 0.079, 0.019),
    ("17.", 0.035, 0.080, 0.017),
    ("Thank you for your gift (lit. I thank for gift).", 0.063, 0.115, 0.047),
    ("18. Dziękuję za prezent.", 0.706, 0.127, 0.020),
    ("18.", 0.035, 0.128, 0.017),
    ("Do you study here? Do you work?", 0.059, 0.166, 0.039),
    ("19. Studiujesz tu/tutaj? Pracujesz?", 0.706, 0.173, 0.019),
    ("19.", 0.035, 0.175, 0.019),
    ("She works a lot.", 0.062, 0.216, 0.023),
    ("20.", 0.035, 0.220, 0.017),
    ("20. (Ona) dużo pracuje.", 0.705, 0.221, 0.020),
    ("They live not far from here.", 0.062, 0.261, 0.029),
    ("21.", 0.036, 0.268, 0.017),
    ("21. (Oni) mieszkaja niedaleko stad.", 0.705, 0.268, 0.022),
    ("22. Thanks, but we're in a hurry.", 0.034, 0.310, 0.032),
    ("22. Dzięki, ale się spieszymy.", 0.703, 0.315, 0.019),
    ("We love reading and travelling.", 0.056, 0.355, 0.027),
    ("23. Kochamy czytać i podróżować.", 0.703, 0.361, 0.019),
    ("23.", 0.035, 0.361, 0.019),
    ("Where are you?", 0.059, 0.405, 0.023),
    ("24. Gdzie jesteś?", 0.703, 0.407, 0.019),
    ("24.", 0.035, 0.408, 0.017),
    ("25. Maybe he's having a bad day.", 0.036, 0.451, 0.028),
    ("25. Może (on) ma zły dzień.", 0.703, 0.454, 0.021),
    ("26. Everything is new and difficult for me.", 0.036, 0.498, 0.030),
    ("26. Wszystko jest dla mnie nowe i trudne.", 0.703, 0.501, 0.019),
    ("I understand that it's important, but he is", 0.067, 0.535, 0.031),
    ("Rozumiem, że to jest ważne, ale on", 0.735, 0.540, 0.024),
    ("27.", 0.036, 0.548, 0.017),
    ("27. teraz odpoczywa.", 0.704, 0.554, 0.037),
    ("resting now.", 0.068, 0.557, 0.018),
    ("I'm sorry. Your flight is / has been cancelled.", 0.062, 0.591, 0.028),
    ("28. Przykro mi. Twój lot jest odwołany.", 0.703, 0.594, 0.021),
    ("28.", 0.036, 0.595, 0.019),
    ("29. I love making cakes!", 0.036, 0.641, 0.019),
    ("29. Kocham robić ciasta!", 0.703, 0.641, 0.019),
    ("We don't have children.", 0.058, 0.686, 0.017),
    ("30. Nie mamy dzieci.", 0.703, 0.687, 0.019),
    ("30.", 0.038, 0.688, 0.017),
    ("31.", 0.039, 0.735, 0.019),
    ("31. (Czy on) jest bardzo zajęty?", 0.705, 0.735, 0.019),
    ("Is he very busy?", 0.064, 0.736, 0.017),
    ("32. I travel a lot.", 0.038, 0.782, 0.017),
    ("32. Dużo podróżuję.", 0.703, 0.783, 0.023),
    ("33. I think you're late too often.", 0.039, 0.828, 0.019),
    ("33. Myślę, że za/zbyt często się spóźniasz.", 0.703, 0.829, 0.021),
    ("Przepraszam, ale zamykamy za dzie-", 0.735, 0.869, 0.019),
    ("34.", 0.703, 0.876, 0.019),
    ("34. I'm sorry, but we're closing in ten minutes.", 0.039, 0.878, 0.026),
    ("sięc minut.", 0.734, 0.886, 0.018),
    ("35. Can you hear it? (lit. You hear it?)", 0.039, 0.923, 0.021),
    ("35. Słyszysz to?", 0.703, 0.925, 0.021),
    ("36. Zaczynamy? (Czy) jesteś gotowy?", 0.703, 0.972, 0.019),
    ("36. Shall we start? (lit. We start?) Are you ready?", 0.039, 0.972, 0.029),
]
T = []
for text, x, y, h in raw:
    right = 0.47 if x < 0.5 else 0.99
    T.append(S(text, x, y, max(right - x, 0.02), h))

R = analyze(T, mode="numbered")
print("pairs:", len(R["num"]), "problems:", R["prob"], "leftovers:", R["left"])
assert len(R["num"]) == 21, R["num"]
assert R["prob"] == [], R["prob"]
print("OK: 21 pairs, no problems")
