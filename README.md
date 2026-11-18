# شوارع الشام 3D / Sham Streets 3D

مشروع لعبة عالم مفتوح سورية أصلية للأندرويد باستخدام Godot 4. يحتوي هذا الإصدار التطويري على منطقة واحدة مستوحاة من سوق حلب، وسيارة قابلة للقيادة، ومهمة توصيل ومتجر ملابس وحفظ محلي، إضافة إلى مارة ومرور ودورية وخريطة مصغرة.

## التشغيل

افتح `project.godot` في Godot 4.6.3 وشغّل المشهد الرئيسي باستخدام F6 من `main.tscn` أو F5 من المشروع. استخدم الأسهم للحركة والقيادة وShift للركض وSpace للقفز أو الفرملة. استخدم E للتفاعل وF5 للحفظ أثناء اللعب خارج المحرر. حرّك الكاميرا مع الضغط على زر الفأرة الأيمن.

على اللمس، اسحب النصف الأيسر من الشاشة للحركة أو القيادة، واسحب المساحة الفارغة في النصف الأيمن لتدوير الكاميرا. اقترب من السيارة واضغط «تفاعل» للصعود، ثم أوقفها قبل النزول. اتبع العلامة الأرضية لتسلّم الطلب وتسليمه ثم زيارة متجر الملابس.

## الاختبار المحلي

نفّذ الأوامر من جذر المشروع باستخدام Bash ومجلد بيانات مؤقت منفصل عن حفظ اللاعب.

```bash
godot --headless --editor --import --path . --quit
XDG_DATA_HOME=$(mktemp -d) godot --headless --fixed-fps 60 --path . \
  --script res://tests/playable_smoke.gd -- --isolated-save
```

## بناء أندرويد

ثبّت قوالب تصدير Godot المطابقة لإصدار المحرك وOpenJDK 17 وAndroid SDK. اضبط مسارات Java وAndroid SDK في إعدادات المحرر وفق [وثائق التصدير الرسمية](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).

```bash
mkdir -p build
godot --headless --path . --export-debug "Android Debug" build/sham-streets-debug.apk
```

للـAAB، ثبّت قالب Android لمشروع Gradle من قائمة Project في Godot، واضبط توقيع الإصدار محلياً، ثم نفّذ الأمر التالي. اعتمد معرّف الحزمة مع مالك المشروع قبل أول نشر. ارفع رمز الإصدار لكل إصدار لاحق. احفظ بيانات التوقيع خارج المستودع.

```bash
godot --headless --path . --export-release "Android Release" build/sham-streets.aab
```

راجع [سجل التطوير والاختبارات](docs/PROGRESS.md).
