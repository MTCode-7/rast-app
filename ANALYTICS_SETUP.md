# Analytics setup

## Firebase

1. Create an Android app in the Firebase project with package name `com.rast.labs`.
2. Download `google-services.json` and place it at `android/app/google-services.json`.
3. Create an iOS app with the Runner bundle identifier shown in Xcode, then place `GoogleService-Info.plist` inside `ios/Runner/` and add it to the Runner target in Xcode.
4. Run:

```text
flutter pub get
flutter clean
flutter run
```

Firebase Analytics is initialized from `lib/main.dart`. Firebase automatically reports `first_open` and session information. The app additionally reports:

- `app_open`
- `login`
- `sign_up`
- `begin_checkout`
- `purchase`
- `subscribe` (available for a future subscription flow)
- user ID after login

Use Firebase Analytics DebugView while testing. Do not send phone numbers, email addresses, names, tokens, or other personally identifiable information as event parameters.

## Snap: Pixel vs mobile app measurement

No Snap Pixel has been installed yet. A Snap Pixel is a web tag and is only
appropriate for a website. This project is primarily an Android/iOS app, so
mobile install attribution must use Snap's app measurement/attribution SDK or
Snap's supported mobile measurement integration. Adding a web Pixel script to
the Flutter mobile build would not measure app installs.

The Dart code sends the same events to an optional native channel:

```text
com.rast.labs/snap_app_events
```

The channel method is `track_event` with `{name, parameters}`. It intentionally
does nothing until the official Snap mobile measurement SDK is selected and
configured. Snap Kit's Login Kit, Creative Kit, and Camera Kit are different
products and should not be installed as an advertising measurement SDK by
mistake.

To finish Snap attribution, you must provide/configure:

1. The Snap Ads Business account and the app's Android package/iOS bundle ID.
2. The Snap App ID or the exact mobile measurement product shown in Snap Ads
	Manager.
3. Any Android/iOS SDK credentials requested by Snap's current documentation.
4. App Store and Google Play links for install attribution and testing.

The App ID is an identifier and may be placed in native app configuration.
Never put a Snap access token, secret, or Conversions API token in Dart,
Android resources, iOS plist files, or the Git repository. Those belong on a
backend/server-side integration. A web Pixel ID is also not a secret. The web
Pixel integration is prepared in `web/snap_config.js` and `web/snap_pixel.js`.
Put the value from Snap Ads Manager here:

```js
window.RAST_SNAP_PIXEL_ID = 'YOUR_PIXEL_ID';
```

The configuration key is `RAST_SNAP_PIXEL_ID`. Keep the value empty until you
receive the real Pixel ID, then rebuild and deploy the Flutter web app. This
does not replace mobile app attribution.

The app now reads the value from Firebase Remote Config instead. Create a
Remote Config parameter with:

```text
Key: snap_pixel_id
Default value: (empty)
```

Set the value to the Pixel ID from Snap Ads Manager, publish the Remote Config
change, and restart the app. No new store release is needed for later value
changes. The app keeps a one-hour fetch interval to avoid excessive requests.

## Event locations

- App startup: `lib/main.dart`
- Login and registration: `lib/features/auth/screens/login_screen.dart` and `lib/features/auth/screens/register_screen.dart`
- Cart payment: `lib/features/cart/screens/cart_screen.dart`
- Direct booking payment: `lib/features/bookings/screens/book_flow_screen.dart`
- Logout clears the Firebase/Snap user ID from `lib/features/profile/screens/profile_screen.dart`
