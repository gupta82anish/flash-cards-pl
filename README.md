# flash-cards-pl
Native iOS app for me to quickly scan a book page to create flash cards 

# Polish Pairs — week 1 test app

Scans pages of your Polish book and lists the Polish–English pairs it finds. The app doesn't save anything yet.

## Run it on your iPhone (about 10 minutes)

1. Unzip, then double-click `PolishPairs.xcodeproj` to open it in Xcode.
2. If Xcode doesn't know your Apple ID yet: **Xcode → Settings → Accounts → +** and sign in.
3. In the left sidebar click **PolishPairs** (blue icon) → target **PolishPairs** → **Signing & Capabilities** → set **Team** to *Your Name (Personal Team)*.
   - If Xcode says the bundle identifier isn't available, change it to something unique, e.g. `pl.yourname.polishpairs`.
4. Connect your iPhone with a cable, unlock it, and tap **Trust** if it asks.
5. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode**. The phone restarts.
6. In Xcode's top bar, choose your iPhone as the run destination and press **▶ Run** (⌘R).
7. The first time, the iPhone blocks the app as an untrusted developer. Go to **Settings → General → VPN & Device Management → your Apple ID → Trust**, then press Run again.

With a free Apple ID the app stops opening after 7 days. Press Run again to reinstall it.

## Test it

1. At the top of the app, check for the green line **Polish text recognition: available**, then set **Page type** (Table / Numbered / Auto) to match what you're about to scan.
2. **Tables:** set Page type to **Table**, tap **Scan pages**, scan one vocabulary page, and tap **Save**.
3. **Numbered exercises:** set Page type to **Numbered**; in **one** scan, capture the English page and then the Polish page (or a single page that has both columns), then tap **Save**.
4. **Choose photos** lets you test with photos you've already taken.
5. Tap **Copy results** and paste the report into the chat with Claude.
6. Goal: 5 table pages and 5 exercises. For one of them, turn **Language correction** on, tap **Re-run on the same pages**, and send both reports.

## If Xcode shows an error

The project builds cleanly for the simulator (`xcodebuild … -sdk iphonesimulator build`). If a build still fails on your Mac — signing, a device SDK mismatch, etc. — copy the red error text from Xcode (the Issue navigator, ⌘5) and paste it into the chat.

## Files

| File | What it does |
| --- | --- |
| `DocumentScanner.swift` | Apple's page scanner (edge detection, flattening) |
| `TextRecognizer.swift` | On-device text recognition (Polish + English); retries sideways photos; splits merged table cells |
| `LanguageTagger.swift` | Tags text as Polish or English |
| `Analyzer.swift` | Pairing rules: vocabulary tables by row, numbered exercises by number |
| `ReportBuilder.swift` | The text report you paste back |
| `ContentView.swift` | The test screen |
