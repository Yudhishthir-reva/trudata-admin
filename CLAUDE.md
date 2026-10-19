# Truedata (trudata-admin)

iOS admin app for the Truedata / SpiceMonk distribution business. SwiftUI + Combine,
CocoaPods, iOS 16 minimum. Mirrors an existing Android app — several comments reference
Android behaviour as the spec.

## Build

```bash
~/.claude/scripts/ios-build.sh          # builds, prints only errors (not 5000 log lines)
~/.claude/scripts/ios-build.sh -w       # include warnings
```

Always open `Truedata.xcworkspace`, never `Truedata.xcodeproj` — CocoaPods.
The workspace lists ~20 pod schemes; the app scheme is `Truedata`.

Pods: IQKeyboardManagerSwift, FirebaseCore, FirebaseMessaging. **No FirebaseRemoteConfig** —
see App Review constraints below.

**New `.swift` files must be registered in `project.pbxproj`** — this project does not
use Xcode 16 synchronized folders, so a file on disk is not compiled until it is added:

```bash
python3 ~/.claude/skills/ios-mvvm-feature/scripts/add_to_xcodeproj.py \
  --project Truedata.xcodeproj/project.pbxproj --group Screens \
  Truedata/Screens/MyFeature/MyFeatureScreen.swift
```

Symptom of forgetting: "Cannot find 'MyFeatureScreen' in scope" on a file that exists.

## Code intelligence (SourceKit-LSP)

`buildServer.json` binds SourceKit-LSP to this workspace, so go-to-definition,
hover and cross-file diagnostics work without a full build. Both it and `.compile`
are gitignored — they hold absolute paths and a DerivedData hash specific to one
machine.

They go stale when files are added or build settings change. Symptom: "Cannot find
type X in scope" on a file that builds fine. Refresh:

```bash
xcode-build-server parse -s ~/Library/Developer/Xcode/DerivedData/Truedata-*/
```

If `.compile` comes back near-empty, the newest build log was an incremental build
that compiled nothing — do a clean build first, then re-run the command above.

On a fresh clone, generate the binding once:

```bash
brew install xcode-build-server
xcode-build-server config -workspace Truedata.xcworkspace -scheme Truedata
```

## Architecture

Hand-rolled MVVM over Combine. One folder per feature, up to four files:

```
Truedata/Screens/<Feature>/
├── <Feature>Models.swift          response DTOs
├── <Feature>ServiceManager.swift  one method per endpoint
├── <Feature>ViewModel.swift       ObservableObject
└── <Feature>Screen.swift          SwiftUI View
```

`Screens/ApproveBills/` is the cleanest reference — copy its shape for new features.
The `ios-mvvm-feature` skill has the full templates.

```
Truedata/
├── Core/
│   ├── Network/      NetworkServiceManager (singleton), LenientDecoding, JSONValue
│   ├── Router/       APIRouter — ~136 endpoints, RouterManagable defaults
│   ├── AppRootManager.swift    root switching: .splash / .auth / .home
│   └── UserDefaultManager.swift  session storage, `authHeader`
├── Utility/          CommonViews, AppTheme, AppFilterComponents, InputField, ...
├── Extensions/       Color+, String+, View+Keyboard, View+NoInternet
└── Screens/          27 feature folders
```

Entry point is `TruedataApp.swift` → `RootContainerView`, which switches on
`AppRootManager.shared.currentRoot`. App is locked to light mode and
`.dynamicTypeSize(.large)`, with screenshot protection on.

## Conventions that matter

**Lenient decoding is mandatory for API models.** The backend returns `3`, `"3"` and
`3.0` for the same field, and `message` is sometimes a string and sometimes an array.
Use `Core/Network/LenientDecoding.swift` helpers (`decodeStringLeniently`,
`decodeIntLeniently`, `decodeBoolLeniently`, `decodeDoubleLeniently`) in a hand-written
`init(from:)`. Plain synthesized `Decodable` will break in production.

**`[weak self]` on both `sink` closures** — the completion closure too, not just
`receiveValue`. Without it the ViewModel retains itself through `cancellables`.

**ServiceManager takes typed arguments** and builds the `[String: Any]` params itself.
ViewModels should not assemble param dictionaries.

**Server failure is not a Combine failure.** `success == false` arrives through
`receiveValue`; handle it there and fall back to a human-readable default when
`message` is empty.

**Reuse `Utility/CommonViews.swift`** before writing UI: `AppTopBar`, `AppSearchBar`,
`AppContentState` (loading / error / empty in one wrapper), `AppEmptyState`,
`PrimaryActionButton`, `FlowLayout`. Colours come from `DashboardTheme`
(`Screens/Home/DashboardCardStyles.swift`), not hex literals scattered in views.

**Role gating goes through `DashboardRole`** (`Screens/Home/DashboardRole.swift`) —
`isOfficeStaff`, `isPrivilegedRole`, `canViewSellerMobile`, `canOpen(role:route:)` etc.
Do not compare role strings inline in a view.

**Search before adding an endpoint.** `APIRouter` has ~136 endpoints with near-duplicates
(`orderListV2`, `orderListV3`, `allOrderList`) — the one you need may exist. A few features
(CashCollection, PaymentAdvance) bypass `APIRouter` with their own `RouterManagable` struct
that interpolates a path prefix, so grep for the raw path too.

## Environment

`Truedata/Utility/AppConstant.swift`:

```swift
let currentEnvironment: RequestEnvironmentType = .stagging
```

That single line switches staging / production. **Currently set to `.production`.**
Check it before any release build — and note the test accounts are staging-only, so a
production build will return 422 from `V2/home3` for them.

## App Review constraints (do not reintroduce)

The app was rejected under **Guideline 2.3.1(a) — hidden features** for two things. Both are
removed; putting either back will get it rejected again, and the account is now in extended
review:

- **No screen-capture or screen-recording detection.** `UIScreen.isCaptured`,
  `UIScreen.capturedDidChangeNotification`, blocking overlays, and the `UITextField`
  secure-canvas trick (reaching into `_UITextLayoutCanvasView`) are all gone. Apple cited
  "screen recording detection that blocks content visibility".
- **No Firebase Remote Config.** The shared `spicemonk-ecosys` project serves an
  `app_update_config` parameter that names a different app (`com.birdtm.app`) and links an
  APK on GitHub. iOS never read it but still fetched it, which Apple cited as "remote
  configuration referencing a different application". The SDK is unlinked; the app makes no
  Remote Config fetch.

If remote configuration is ever needed again, the parameter must be conditioned to the
Android app in the Firebase console first, and the iOS feature must be visible and
documented — not something that changes behaviour after review.

## Gotchas

- `NetworkServiceManager.request` force-casts params (`as! [String: Any]`). A params
  shape that disagrees with the endpoint's `contentType` crashes instead of erroring.
- `RequestConstants.EndPoint` is a typealias for `RouterManagable`; protocol and
  implementation signatures look mismatched but compile. Leave it.
- No `@MainActor`, essentially no async/await — the codebase is Combine throughout.
  Stay consistent unless a migration is explicitly asked for.
- `Pods/` is on disk but gitignored, not committed. Never edit or search it.
- Some screens are 600+ lines in a single `body`. Do not take them as the house style;
  split new work into sub-views.
