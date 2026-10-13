# Deploying Reserve (Android)

This guide takes the Reserve Flutter app from this Windows PC to testers' phones and, later, to Google Play.
Facts were checked against official Google and Flutter pages in September 2026; the links are in [Sources](#sources).
Policies change, so open the linked pages again before you submit.

> **Read this first: Reserve sells alcohol.**
> Reserve is a liquor-shopping app for India. That changes what you can publish and where:
>
> - **Google Play policy.** Play bans apps that sell tobacco, with only narrow exceptions. It does not ban alcohol shops outright, but under
>   the *Tobacco and Alcohol* section of the Developer Program Policy, apps must not "encourage the illegal or
>   inappropriate use of alcohol". The same section gives examples of what isn't allowed: selling alcohol to minors or
>   showing minors drinking, and presenting excessive, binge or competition drinking in a good light. For you this
>   means:
>   - Only sell where it is legal.
>   - Add a real age check.
>   - Declare an 18+ audience.
>   - Keep promotions sober.
>
>   Expect a manual, and possibly longer, review, and be ready to show the business's licences.
> - **Indian law (general information, not legal advice).** Alcohol is a state subject in India. Every state and
>   union territory runs its own excise rules and licences, sets its own legal drinking age (between 18 and 25), and
>   decides whether online sale or home delivery is allowed at all. Gujarat, Bihar, Nagaland, Mizoram and Lakshadweep
>   are "dry" and ban sale. Only some states have ever allowed licensed home delivery, and the rules keep changing.
>   **Before any real order is taken, a licensed retailer, the state excise department and an Indian lawyer need to
>   confirm that the delivery model is legal in each state you serve.** Google Play can only limit an app by country,
>   not by state, so the app itself must block deliveries to states and PIN codes where it isn't licensed.
> - **The current build is a demo.** It runs offline on sample data and uses simulated sign-in, payments and delivery.
>   You can share it with testers today (sections 3 and 5). Don't publish it to *production* on Play until the
>   [launch checklist](#6-launch-checklist-what-the-app-still-needs) is done.

**Contents**

1. [Prepare the release](#1-prepare-the-release)
2. [Create the upload keystore and key.properties](#2-create-the-upload-keystore-and-keyproperties)
3. [Build the AAB / APK](#3-build-the-aab--apk)
4. [Publish on Google Play, step by step](#4-publish-on-google-play-step-by-step)
5. [Share with testers without the Play Store](#5-share-with-testers-without-the-play-store)
6. [Launch checklist (what the app still needs)](#6-launch-checklist-what-the-app-still-needs)
7. [Sources](#sources)

---

## 1. Prepare the release

| Item | Where | Current value / action |
|---|---|---|
| **Application ID** | `android/app/build.gradle.kts` → `applicationId` | `com.reserve.liquor`. **This is permanent.** Once you upload to Play, it can never change. If you want a different ID (for example `in.yourcompany.reserve`), change it now. The `namespace` (`com.reserve.reserve_liquor`) is only the Kotlin code package, and users never see it. |
| **App name** (on the home screen) | `android/app/src/main/AndroidManifest.xml` → `android:label` | `Reserve`. The name on the Play listing is set separately in Play Console (max 30 characters). |
| **Launcher icon** | `android/app/src/main/res/mipmap-*/ic_launcher.png` | A custom icon is already in place. Consider adding an *adaptive* icon (for example with the `flutter_launcher_icons` package) so it looks right in every launcher shape. Play also needs a separate 512 × 512 PNG icon for the listing. |
| **Version** | `pubspec.yaml` → `version: 1.0.0+1` | `1.0.0` is the versionName that users see. `+1` is the versionCode. **Every upload to Play needs a higher versionCode**: `1.0.0+1` → `1.0.1+2` → `1.1.0+3` … |
| **Target API level** | `flutter.targetSdkVersion` | Flutter 3.47.5 sets compileSdk 36, **targetSdk 36** and minSdk 24. That meets Play's rule that new apps and updates must target Android 16 (API 36) from 31 Aug 2026. Nothing to change. |
| **Permissions** | `AndroidManifest.xml` | Only `INTERNET` and `VIBRATE`. No sensitive-permission declaration is needed. |
| **Signing** | `android/app/build.gradle.kts` | Already set up to read `android/key.properties` (next section). Without that file, release builds use the debug key: fine for testers, **rejected by Play**. |

You can also set the version for a single build without editing `pubspec.yaml`:

```powershell
flutter build appbundle --release --build-name=1.0.1 --build-number=2
```

---

## 2. Create the upload keystore and key.properties

The **upload key** signs what you upload to Play. Play then re-signs the app for users with its own *app signing key*
(Play App Signing). Keep the keystore file and both passwords safe. Every future update must be signed with the same
upload key. If you lose it or it leaks, you can make a new key and request an upload key reset in Play Console
(**Protected with Play → Play Store protection → Manage Play app signing → Request upload key reset**). The reset
takes time. APKs you share outside Play (section 5) are signed with the upload key itself, so if you lose that key,
anyone with one of those copies has to uninstall and reinstall to get the next version.

Create a folder outside the project (and outside OneDrive) for the key:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\keystores"
```

Generate the keystore. It asks for a password, your name and organisation details, then a key password. Press **Enter**
at the key-password prompt so the key uses the same password as the keystore:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore "$env:USERPROFILE\keystores\reserve-upload.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

(keytool may warn that JKS is a proprietary format. You can ignore that warning; the command matches Flutter's official instructions.)

Check the key. This also prints the upload key's SHA-1 / SHA-256 fingerprints. For builds that users install from
Play, register the fingerprints of Play's *app signing key* with Firebase or Google sign-in. You'll find them in Play
Console after the first upload.

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\keystores\reserve-upload.jks" -alias upload
```

Create `android/key.properties` from the template:

```powershell
Copy-Item "C:\Users\RioGG\OneDrive\Desktop\reverse liq\android\key.properties.example" "C:\Users\RioGG\OneDrive\Desktop\reverse liq\android\key.properties"
```

Open `android\key.properties` in a text editor and fill in the real values. Use forward slashes in the path:

```properties
storePassword=the-password-you-typed
keyPassword=the-password-you-typed
keyAlias=upload
storeFile=C:/Users/RioGG/keystores/reserve-upload.jks
```

- `key.properties`, `*.jks` and `*.keystore` are already listed in `android/.gitignore`. Never commit or share them.
- Back up the `.jks` file and the passwords somewhere safe that isn't this PC, such as a password manager or an encrypted USB drive.
- If `key.properties` is missing a value, the build stops and tells you which one.

---

## 3. Build the AAB / APK

Open **PowerShell** and put Flutter on the PATH for this window:

```powershell
$env:Path = "C:\src\flutter\bin;$env:Path"
```

```powershell
Set-Location "C:\Users\RioGG\OneDrive\Desktop\reverse liq"
```

Start from a clean build and make sure the tests pass:

```powershell
flutter clean
```

```powershell
flutter pub get
```

```powershell
flutter test
```

### App Bundle (for Google Play)

Play accepts only Android App Bundles (`.aab`) for new apps.

```powershell
flutter build appbundle --release
```

Output: `build\app\outputs\bundle\release\app-release.aab`

Check that the bundle is signed with your upload key and not the debug key. The owner should show your name, not `CN=Android Debug`:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

### APKs (for installing directly on phones)

One small APK per CPU type (recommended for sharing):

```powershell
flutter build apk --release --split-per-abi
```

Output in `build\app\outputs\flutter-apk\`:

| File | Use for |
|---|---|
| `app-arm64-v8a-release.apk` | Almost every phone made after about 2017, including your Android 16 test phone |
| `app-armeabi-v7a-release.apk` | Old 32-bit phones |
| `app-x86_64-release.apk` | Emulators / Chromebooks |

Or build one larger APK that works on every phone:

```powershell
flutter build apk --release
```

Output: `build\app\outputs\flutter-apk\app-release.apk`

### Install the release build on your phone over USB

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s 2b136896 install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

If the install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, a copy signed with a different key (for example the
debug build from `flutter run`) is already on the phone. Uninstall it first. This also clears the app's data on that phone:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s 2b136896 uninstall com.reserve.liquor
```

Optional: make the Dart code harder to reverse-engineer. The symbol files are what turn an obfuscated crash stack
trace back into readable code, so write them **outside** the `build` folder (`flutter clean` deletes `build`), into a
folder named after the version you are building:

```powershell
flutter build appbundle --release --obfuscate --split-debug-info="$env:USERPROFILE\reserve-symbols\1.0.0+1"
```

Keep that folder (back it up with the keystore) for every version you release; you need the matching one to read a crash
report from that version. Change the `1.0.0+1` part to the version in `pubspec.yaml` each time.

---

## 4. Publish on Google Play, step by step

### 4.1 Create the developer account

1. Go to <https://play.google.com/console/signup> and sign in with the Google account that will own the app.
2. Choose the account type:
   - **Organisation.** Recommended for a liquor business, because the licensed business should be the publisher.
     Needs a **D-U-N-S number**. Getting one from Dun & Bradstreet is free but can take up to 30 days. You also need
     the organisation's website, address and phone number.
   - **Personal.** For an individual. Personal accounts created after 13 Nov 2023 must run a closed test before they
     can go to production (see 4.5).
3. Pay the **US$25 one-time fee**. Use a credit or debit card in your legal name; prepaid cards aren't accepted.
4. Complete **identity verification**. Google may ask for a government ID that matches the payments profile. You
   also verify your contact email and phone, and confirm you have an Android device by using the Play Console app.

### 4.2 Create the app

**Play Console → Create app** → app name `Reserve`, default language English (India) / en-IN, **App**, **Free**. Then
accept the Developer Program Policies, the US export-law declaration and the Play App Signing terms.

### 4.3 Complete "App content" (Policy → App content)

| Declaration | What to enter for Reserve |
|---|---|
| **Privacy policy** | A public HTTPS URL, such as a page on the business website. It must also be linked inside the app, from Profile → Terms & privacy. |
| **App access** | If reviewers need to sign in, give working test login details and steps. |
| **Ads** | "No, my app does not contain ads" (true for the current build). |
| **Content rating** | Fill in the IARC questionnaire honestly. **Answer yes to every question about alcohol (references to it and selling it).** The rating will be higher than for an ordinary shopping app. |
| **Target audience and content** | Choose **18 and over** only. Never pick an under-18 age group: the app must not appeal to children. |
| **Data safety** | List everything the app collects or shares, such as name, phone, email, profile photo, addresses, order history, location/city and payment details. It must match the privacy policy. The current build keeps the account (name, phone, optional email and photo, and a salted hash of the password) only on the phone and sends nothing off the device; say so accurately, and update the form when a backend is added. |
| **Account deletion** | **Required now**, because this build already lets people create an account inside the app. In-app deletion is built in (**Profile → Edit Profile → Delete account**). Play also asks for a **web link** where users can request deletion (for example a page on the business website with a form or a support email address); prepare it before you submit. |
| **Government / Financial features / Health / News** | No / none. |

### 4.4 Store listing (Grow → Store presence → Main store listing)

- App name (≤ 30 characters), short description (≤ 80), full description (≤ 4000). Describe it as a shop from
  licensed retailers, include responsible-drinking wording, and don't promote excessive or binge drinking.
- App icon: 512 × 512, 32-bit PNG, up to 1 MB.
- Feature graphic: 1024 × 500, JPEG or 24-bit PNG.
- At least 2 screenshots: JPEG or 24-bit PNG, each side between 320 and 3840 px. Take them from your phone with
  the demo data.
- Category: *Shopping* (or *Food & Drink*), plus contact email and website.
- Only use product photos, bottle images and brand logos you have the rights to.

### 4.5 Testing tracks

| Track | Who | Notes |
|---|---|---|
| **Internal testing** | Up to 100 testers you add by email | Available within minutes. Good for a quick check of the Play-signed build. |
| **Closed testing** | Email lists or a Google Group, joined through an opt-in link | **New personal accounts must run a closed test with at least 12 testers who stay opted in for 14 days in a row** before they can apply for production. A tester who leaves and rejoins restarts their 14 days. Then apply from the Dashboard ("Apply for production"). |
| **Open testing** | Anyone with the link or listing | Optional public beta. |
| **Production** | Everyone in the countries you choose | Choose **India only** under *Countries / regions*. |

To release on any track: **Test and release → (track) → Create new release**. On the first upload, Play App Signing
is turned on and Google creates the app signing key. Upload `app-release.aab`, add release notes, then click
**Next → Save → Send for review**. For production, you can start with a **staged rollout** (for example 10%).

### 4.6 Review

Google reviews every new app and most updates. For some developer accounts, Google says reviews can take "up to
seven days or longer in exceptional cases", and alcohol-related apps may get extra checks. If the app is rejected, the email names the policy. Fix the problem,
raise the versionCode, and upload again. You can appeal from the Policy status page.

---

## 5. Share with testers without the Play Store

### Option A: send the APK directly (fastest)

1. Build `flutter build apk --release --split-per-abi` (section 3).
2. Send `app-arm64-v8a-release.apk` by Google Drive, email or a messaging app.
3. The tester taps the file, allows **Install unknown apps** for the app they opened it from, and installs.
   Play Protect may show a warning for an unknown developer; testers can choose *Install anyway*.
4. For later versions, sign with the same key (the upload keystore) and raise the build number. Otherwise the
   update won't install over the old version.

> **Android developer verification.** Google now requires apps installed on certified Android phones to come from a
> verified developer, **including sideloaded APKs**. Enforcement starts on **30 Sep 2026 in Brazil, Indonesia,
> Singapore and Thailand**, and spreads worldwide from **2027**. India isn't in the first group, but it will be.
> Register your identity and package name (`com.reserve.liquor`) through Play Console or the Android Developer
> Console before then. For small groups, a free *limited distribution* account lets hobbyists share an app with up
> to 20 devices without an ID or fee. Installing with `adb` from your own PC (section 3) keeps working without
> verification.

### Option B: Firebase App Distribution (tidy tester management, free)

1. Create a Firebase project at <https://console.firebase.google.com> and add an **Android app** with package name
   `com.reserve.liquor`. The app code doesn't need any changes just to distribute builds.
2. Open **Release & Monitor → App Distribution**, drag in the APK, add testers by email (or a tester group) and
   write release notes.
3. Testers get an email invite. They accept it, then install from the web link or from the Firebase App Tester app.
   They also get notified about new builds.
4. To distribute the `.aab` instead, you first need to link the Firebase project to your Play Console app.

### Option C: Play internal testing

If you already have a Play developer account, the internal testing track (section 4.5) is the most "real"
option. Testers install from the Play Store app through an opt-in link, and Play delivers updates automatically.

---

## 6. Launch checklist (what the app still needs)

The current app is a front-end demo. Before it takes real orders from the public:

**Legal and licensing**
- [ ] A licensed retailer partner (or your own excise licences) for every state served, and written legal advice
      that the online ordering and delivery model is allowed there.
- [ ] Availability limited by state and PIN code in the app: block dry states and unlicensed areas, and apply
      state-specific rules such as the legal age (18–25), permitted hours, dry days and quantity limits.
- [ ] Terms of service, a refund/cancellation policy and a **privacy policy on a public URL**, compliant with
      India's Digital Personal Data Protection Act, 2023. Linked from the Play listing and inside the app.
- [ ] Rights to all product photos, brand names/logos and the stock avatar images. The current images were cropped
      from design references.
- [ ] Marketing that complies with India's restrictions on liquor advertising (no direct or surrogate ads).

**Age verification**
- [ ] Replace the self-declared "I am 18+" gate with date-of-birth entry and the correct age for the user's state.
- [ ] ID/KYC verification at sign-up (for example through a licensed KYC provider or DigiLocker), and a
      **mandatory ID check at the door on delivery**, with delivery refused to anyone under age or intoxicated.

**Backend and accounts**
- [ ] A real backend: product catalogue, stock and prices per store, orders, and delivery tracking. Today
      everything is local sample data in `lib/data/sample_data.dart` and `lib/state/app_state.dart`.
- [ ] Real authentication (for example phone OTP) and sessions. Account deletion must then also delete the account's
      data on the server (the current in-app **Delete account** only removes the on-phone account), and the web
      deletion link must keep working.
- [ ] Save each account's orders, addresses, cards and preferences (on the server). Today only the account itself,
      the session and the delivery city survive a restart; the cart, orders and other shopping data are demo data
      that reset when the app restarts or the user logs out.
- [ ] Remove the demo content: sample orders, addresses, the scripted chat, and the fake order number used in help chat.
- [ ] Push notifications, crash reporting (for example Firebase Crashlytics) and analytics with user consent.

**Payments**
- [ ] An Indian payment gateway (for example Razorpay, PayU or Cashfree) for UPI, cards and net banking. Physical
      goods don't use Google Play Billing. Check that the gateway accepts alcohol merchants.
- [ ] Never store card numbers in the app. Use the gateway's tokenised saved cards, as RBI rules require.
- [ ] Invoices with the correct state excise duty and taxes.

**Store readiness**
- [ ] Upload keystore created and backed up, versionCode raised for every upload.
- [ ] Data safety, content rating (alcohol), 18+ target audience, privacy policy URL and app access details filled in.
- [ ] Account deletion declared: the in-app path (Profile → Edit Profile → Delete account) and a public web link.
- [ ] Store listing text, 512 px icon, feature graphic and screenshots, in line with the alcohol policy.
- [ ] Tested on a few phones, including small screens (360 dp) with large font size, and on Android 16 (targetSdk 36).
- [ ] Closed test done (12 testers × 14 days) if you publish from a personal account.

---

## Sources

Google Play and Android (official):
- Flutter: Build and release an Android app: <https://docs.flutter.dev/deployment/android>
- Target API level requirements (API 36 from 31 Aug 2026): <https://support.google.com/googleplay/android-developer/answer/11926878>
- Testing requirements for new personal accounts (12 testers, 14 days): <https://support.google.com/googleplay/android-developer/answer/14151465>
- Register a developer account (US$25 fee, verification): <https://support.google.com/googleplay/android-developer/answer/6112435>
- Required account information (D-U-N-S for organisations): <https://support.google.com/googleplay/android-developer/answer/13628312>
- Create and set up your app: <https://support.google.com/googleplay/android-developer/answer/9859152>
- Prepare your app for review (App content declarations): <https://support.google.com/googleplay/android-developer/answer/9859455>
- Play App Signing: <https://support.google.com/googleplay/android-developer/answer/9842756>
- Set up an open, closed or internal test (internal: up to 100 testers): <https://support.google.com/googleplay/android-developer/answer/9845334>
- Store listing preview assets (icon, feature graphic, screenshots): <https://support.google.com/googleplay/android-developer/answer/9866151>
- Publishing status and review times: <https://support.google.com/googleplay/android-developer/answer/9859751>
- Developer Program Policy (incl. Tobacco and Alcohol, Data safety, account deletion): <https://support.google.com/googleplay/android-developer/answer/17190352>
- Inappropriate content policy (Tobacco and Alcohol): <https://support.google.com/googleplay/android-developer/answer/9878810>
- Policy Center: <https://play.google.com/about/developer-content-policy/>
- Android App Bundles (required for new apps since Aug 2021): <https://developer.android.com/guide/app-bundle>
- Android developer verification: <https://developer.android.com/developer-verification>
- Limited distribution accounts: <https://developer.android.com/developer-verification/guides/limited-distribution>
- Developer verification FAQ (ADB installs work without verification): <https://developer.android.com/developer-verification/guides/faq>
- Firebase App Distribution (Android, console; AABs need a Play link): <https://firebase.google.com/docs/app-distribution/android/distribute-console>
- Firebase App Distribution, tester setup: <https://firebase.google.com/docs/app-distribution/get-set-up-as-a-tester?platform=android>

India (for background only; confirm the current rules with each state's excise department and a lawyer):
- Constitution of India, Seventh Schedule, List II (State List), Entry 8 "Intoxicating liquors": <https://www.mea.gov.in/Images/pdf1/S7.pdf>
- Digital Personal Data Protection Act, 2023: <https://www.meity.gov.in/data-protection-framework>
