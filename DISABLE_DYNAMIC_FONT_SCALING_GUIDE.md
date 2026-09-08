# Guide: Disabling / Locking Dynamic Font Scaling Across Apps

When users change the font size in their mobile system settings (iOS **Settings → Display & Brightness / Accessibility → Text Size** or Android **Settings → Display → Font Size**), apps with dynamic scaling can have broken layouts, truncated text, and overflowing cards.

This guide provides ready-to-use snippets to **lock font size to standard default (100% scale)** across **iOS (SwiftUI & UIKit)** and **Android (Jetpack Compose / KMP & XML Views)**.

---

## 1. iOS — SwiftUI (Recommended)

In SwiftUI (iOS 15+), apply `.dynamicTypeSize(.large)` at the root view or `WindowGroup`. In iOS, `.large` represents the standard default system font size (1.0x).

### Method A: Lock Globally in App Entry Point (`App.swift`)
```swift
import SwiftUI

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .dynamicTypeSize(.large) // 🔒 Locks all fonts to standard 100% size
        }
    }
}
```

### Method B: Allow a Controlled Range (Optional)
If you want to allow slightly smaller fonts but prevent extra large / accessibility sizes:
```swift
RootView()
    .dynamicTypeSize(...DynamicTypeSize.large) // Max limit is standard large
```

### Method C: In `UIHostingController` (if integrating with UIKit / Navigation)
```swift
let hostingController = UIHostingController(
    rootView: YourSwiftUIView()
        .dynamicTypeSize(.large)
)
```

---

## 2. Android — Jetpack Compose / Compose Multiplatform (KMP)

In Jetpack Compose, text sizes use `sp`, which automatically multiplies by the system `fontScale`. To lock the font scale to `1.0f`, override `LocalDensity` using `CompositionLocalProvider`:

### In `MainActivity.kt` or `AppTheme.kt` / Root Composable:
```kotlin
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

@Composable
fun LockFontScale(content: @Composable () -> Unit) {
    val currentDensity = LocalDensity.current
    CompositionLocalProvider(
        LocalDensity provides Density(
            density = currentDensity.density,
            fontScale = 1.0f // 🔒 Locks system font scaling to 1.0x
        )
    ) {
        content()
    }
}
```

### Usage in `MainActivity.kt`:
```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            LockFontScale {
                YourAppTheme {
                    MainNavigation()
                }
            }
        }
    }
}
```

---

## 3. Android — Native XML / Views (`BaseActivity`)

If any of your apps use standard Android XML Views or `ViewBinding`, override `attachBaseContext` in your `BaseActivity`:

```kotlin
import android.content.Context
import android.content.res.Configuration
import androidx.appcompat.app.AppCompatActivity

open class BaseActivity : AppCompatActivity() {
    override fun attachBaseContext(newBase: Context) {
        val config = Configuration(newBase.resources.configuration)
        config.fontScale = 1.0f // 🔒 Force 1.0x scale
        val context = newBase.createConfigurationContext(config)
        super.attachBaseContext(context)
    }
}
```

---

## 4. iOS — UIKit (`UIWindow` / `SceneDelegate`)

If using UIKit in older projects, override the trait collection on the root window:

```swift
import UIKit

// In SceneDelegate.swift or AppDelegate.swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    let window = UIWindow(windowScene: windowScene)
    
    // iOS 17+:
    if #available(iOS 17.0, *) {
        window.traitOverrides.preferredContentSizeCategory = .large
    }
    
    // iOS 13-16:
    window.overrideUserInterfaceStyle = .light
    
    self.window = window
    window.makeKeyAndVisible()
}
```

---

## 5. Quick Verification Checklist

| Platform | Location | Code Snippet |
| :--- | :--- | :--- |
| **iOS SwiftUI** | `WindowGroup` in `App.swift` | `.dynamicTypeSize(.large)` |
| **Android Compose** | `setContent` in `MainActivity.kt` | `CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale = 1.0f))` |
| **Android XML** | `BaseActivity.kt` | `config.fontScale = 1.0f` in `attachBaseContext` |
