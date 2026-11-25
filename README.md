# MMY.YE – النظام الإداري الإعلامي (الإعلام الحربي اليمني)

تطبيق Flutter واحد لـ **Android وWindows فقط**، يعمل دون إنترنت وبقاعدة SQLite محلية مستقلة لكل جهاز.
لا خادم ولا مزامنة. نقل البيانات يدوي فقط عبر ملف `.mmy` (تصدير/استيراد).

> **الحالة الصادقة:** هذا هيكل أساسي كُتب دون وجود Flutter SDK في بيئة العمل، ولم يُترجَم (compile) ولم تُشغَّل اختباراته بعد.
> **المبني من الشاشات:** الدخول، تغيير كلمة المرور، **المراكز** (بطاقات + ملف بأربع نوافذ + إضافة/تعديل/حذف)، **الكادر الإعلامي** (قائمة بحث وتصفية + ملف بأربعة أقسام + دورات وخبرات). باقي الأقسام ما زال هياكل فارغة (النظرة العامة، الإدارة، المهام، المخزن، التقييم، لوحة التحكم). الصور الشخصية غير مبنية بعد. البصمة تحتاج تجربة على جهاز أندرويد وجهاز ويندوز حقيقيين.

## التشغيل
```bash
flutter create . --platforms=windows,android     # مرة واحدة لتوليد مجلدات المنصات (لن يمس lib/ و assets/)
python3 tools/apply_native_overlay.py           # ينسخ الأيقونات ويطبّق إعدادات أندرويد (البصمة، minSdk، MainActivity)
flutter pub get
flutter test                                  # اختبارات الأمان والحسابات والتصدير/الاستيراد
flutter run -d windows
```
بعد `flutter create` انسخ فوق الملفات المولدة:
- `windows/runner/resources/app_icon.ico` ← موجود هنا (7 مقاسات: 16…256).
- `android/app/src/main/res/` ← موجود هنا: أيقونة تكيفية (foreground / background / monochrome) بمقاسات 108/162/216/324/432 بكسل
  داخل منطقة الأمان 66dp، وأيقونة قديمة `ic_launcher.png` لأندرويد أقل من 8، و`mipmap-anydpi-v26/ic_launcher.xml`.
  (اسم الأيقونة `@mipmap/ic_launcher` هو الافتراضي في `AndroidManifest.xml` بعد `flutter create` فلا يلزم ربط إضافي.)
- `assets/brand/play_store_icon_512.png` ← أيقونة Google Play (512×512، PNG، مربعة بلا حواف مرسومة؛ ترفع في Play Console فقط).

## أين يوضع كل شيء
| الملف | الغرض |
|---|---|
| `assets/brand/logo.svg` | الشعار الأصلي (المصدر المعتمد، يُعرض في الدخول والقائمة) |
| `assets/brand/app_icon_1024.png` | الأصل عالي الدقة 1024 للأيقونة (الإطار والكلمات بلا شريط الموقع) |
| `assets/brand/play_store_icon_512.png` | أيقونة المتجر |
| `assets/brand/logo_full_1024.png` | الشعار الكامل بنسبه (للتقارير وSplash) |
| `lib/core/brand.dart`, `theme.dart` | ألوان الشعار #136031 / #E82629 / #FFFFFF وثيمات فاتح/داكن |
| `lib/core/db/schema.dart` | المخطط الكامل (23 جدولاً) |
| `lib/core/security/password_hasher.dart` | PBKDF2-SHA256 + سياسة كلمة المرور |
| `lib/features/auth/` | الدخول، admin الافتراضي، الإيقاف بعد 5 محاولات/15 دقيقة، تغيير إجباري، البصمة |
| `lib/features/transfer/mmy_package.dart` | صيغة `.mmy`: ZIP + manifest + SHA-256 + تشفير AES-GCM اختياري + دمج + نسخة احتياطية |

## البناء عبر GitHub Actions (دون تثبيت Flutter عندك)
1. أنشئ مستودعاً **خاصاً (Private)** على GitHub، وارفع محتوى هذا المجلد (جذر المستودع يحتوي `pubspec.yaml` و`lib/` و`.github/`).
2. عند كل `push` على `main` (أو من تبويب Actions ← build ← Run workflow) تعمل ثلاث مهام: `test` و`android` و`windows`.
3. بعد النجاح افتح التشغيل ← **Artifacts** ونزّل:
   - `mmy-android-apk` ← ملف `app-release.apk` (يُثبَّت يدوياً على الجهاز بعد السماح بالمصادر غير المعروفة).
   - `mmy-windows` ← ملف zip فك ضغطه وشغّل `mmy_ye.exe` (يجب بقاء ملفات DLL ومجلد data بجانبه).
4. مجلدات `android/` و`windows/` لا تُرفع؛ يولّدها `flutter create` داخل المهمة، وأيقوناتها محفوظة في `native_overlay/`.
5. الـAPK الحالي موقَّع بمفتاح debug (يصلح للتثبيت المباشر لا للنشر في المتجر). للنشر أنشئ keystore خاصاً وخزّنه في GitHub Secrets، ولا ترفعه للمستودع.

## إعدادات المنصات (يطبّقها السكربت تلقائياً؛ مذكورة للمرجع)
**Android** (بعد `flutter create`):
1. `android/app/src/main/AndroidManifest.xml`: أضف داخل `<manifest>`:
   `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`
2. `MainActivity.kt` يجب أن يرث `FlutterFragmentActivity` (شرط `local_auth`):
   `class MainActivity : FlutterFragmentActivity()` مع `import io.flutter.embedding.android.FlutterFragmentActivity`.
3. `android/app/build.gradle(.kts)`: اجعل `minSdk = 23` على الأقل (شرط `flutter_secure_storage` و`local_auth`).
4. حفظ/نقل ملفات `.mmy`: يعمل عبر منتقي الملفات ومشاركة النظام (USB أو Bluetooth أو أي تطبيق ملفات) دون صلاحيات تخزين واسعة.
5. توقيع الإصدار: أنشئ keystore خاصاً بك قبل النشر ولا تحفظه داخل المشروع.

**Windows**: Windows Hello يعمل عبر `local_auth` دون إعداد إضافي. إن ظهر خطأ `sqlite3.dll` فتأكد من `sqlite3_flutter_libs`.

**الخط**: ضع Cairo في `assets/fonts/` وفعّل قسم `fonts` في `pubspec.yaml` ليعمل دون إنترنت.

## ما هو غير مكتمل بالنص (لم يُحسم في الوثيقة)
أوزان التقييم (مزروعة بعلامة `is_final=0`)، معادلة الدرجة، نموذج الصيانة (جدول أولي فقط)، نوافذ ملف المركز الإضافية، تفاصيل سجل المهمة.

## المراحل القادمة
1. بناء شاشات الأقسام (المراكز ← الكادر ← المهام ← المخزن ← التقييم ← التقارير PDF) على المخطط الحالي.
2. صلاحيات الأدوار (مدير/مساعد/أرشيف) كطبقة خدمة تفحص قبل كل كتابة، مع تسجيل `audit_log`.
3. واجهة التصدير/الاستيراد (ملخص، تعارضات، تقرير نجاح/فشل).
4. التقارير PDF بمقاس A4 والأرشفة السنوية.

## تحديثات الأمان (المرحلة 1)
- الاستيراد للمدير فقط (في الواجهة وفي `MmyPackage.import(actor: ...)`).
- تحصين `.mmy`: قائمة بيضاء للأعمدة، رفض مسارات المرفقات غير الآمنة، حدّ للحجم قبل/بعد فك الضغط.
- معرّفات ثابتة لبذور `output_types` و`evaluation_criteria` (كانت تُفشل الاستيراد بين جهازين).
- حقل عبارة سرية في شاشة التصدير/الاستيراد، وحذف الملفات المؤقتة بعد الاستخدام.
- `android:allowBackup="false"` يُضبط في `apply_native_overlay.py`.
- لا يُسجَّل «صرف/إرجاع» في التدقيق إلا عند نجاح العملية؛ رسالة دخول موحّدة وزمن متساوٍ للمستخدم غير الموجود.
- **ما زال مطلوباً:** تشفير القاعدة (SQLCipher)، توقيع بمفتاح خاص، قفل تلقائي وخروج، ربط البصمة بمفتاح، `task_staff`، خط عربي في PDF.
- لم تُشغَّل هذه التعديلات بعد: شغّل `flutter analyze` و`flutter test` (يعملان تلقائياً في GitHub Actions).
