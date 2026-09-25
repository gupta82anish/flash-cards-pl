# Reproduce the pasted on-device report through the mirror.
# Each line: text, x, y, h (w reconstructed from x and page split; width only
# matters for the inline-prefix textX estimate, so approximate generously).
from mirror import analyze, show, S

raw = [
    ("What are you doing?", 0.049, 0.054, 0.058),
    ("1.", 0.035, 0.071, 0.024),
    ("1. Co robisz?", 0.682, 0.073, 0.027),
    ("2. I understand everything.", 0.035, 0.117, 0.062),
    ("2. Wszystko rozumiem.", 0.679, 0.134, 0.029),
    ("3. They watch Netflix every day.", 0.037, 0.179, 0.065),
    ("3. Codziennie ogladaja Netflixa.", 0.679, 0.193, 0.030),
    ("4. I live there.", 0.039, 0.255, 0.043),
    ("4. Mieszkam tam.", 0.679, 0.257, 0.026),
    ("I'm sorry, but I don't remember.", 0.057, 0.309, 0.060),
    ("5. Przepraszam, ale nie pamiętam.", 0.679, 0.317, 0.031),
    ("5.", 0.042, 0.325, 0.024),
    ("6. (On) nie mówi po polsku.", 0.677, 0.376, 0.031),
    ("6. He doesn't speak Polish.", 0.044, 0.378, 0.047),
    ("7. Często to ogladamy.", 0.679, 0.439, 0.026),
    ("7. We often watch it.", 0.047, 0.445, 0.039),
    ("8. (Ona) nic nie rozumie.", 0.677, 0.498, 0.031),
    ("8. She doesn't understand anything.", 0.047, 0.504, 0.047),
    ("9. Zwykle tu/tutaj odpoczywamy.", 0.677, 0.558, 0.029),
    ("9. We usually rest here.", 0.052, 0.571, 0.034),
    ("10. Czekam na autobus.", 0.670, 0.620, 0.027),
    ("I'm waiting for the bus.", 0.066, 0.635, 0.034),
    ("10.", 0.048, 0.638, 0.024),
    ("Niestety już zamykamy. Zapraszamy", 0.706, 0.678, 0.030),
    ("Unfortunately, we are already closing.", 0.080, 0.684, 0.034),
    ("11.", 0.672, 0.691, 0.026),
    ("jutro.", 0.702, 0.704, 0.022),
    ("Please, come back tomorrow (lit. We invite", 0.077, 0.707, 0.037),
    ("11.", 0.052, 0.711, 0.022),
    ("tomorrow).", 0.081, 0.735, 0.028),
    ("12. Nigdy nie słuchasz!", 0.672, 0.763, 0.026),
    ("12. You never listen!", 0.054, 0.784, 0.024),
    ("13. Cały czas mówisz!", 0.671, 0.822, 0.028),
    ("13. You speak all the time!", 0.055, 0.845, 0.031),
    ("Płacimy razem.", 0.696, 0.882, 0.020),
    ("14.", 0.672, 0.884, 0.024),
    ("14. We're paying together.", 0.058, 0.908, 0.036),
    ("15. Kochanie, co gotujesz?", 0.671, 0.942, 0.037),
    ("15.", 0.060, 0.962, 0.024),
    ("Honey, what are you cooking?", 0.081, 0.973, 0.039),
    ("Dublichina nl", 0.740, 0.992, 0.011),
]
# width: to end of its own column (English col ends ~0.47, Polish col ~0.99)
T = []
for text, x, y, h in raw:
    right = 0.47 if x < 0.5 else 0.99
    T.append(S(text, x, y, max(right - x, 0.02), h))

R = analyze(T)
show(R)
