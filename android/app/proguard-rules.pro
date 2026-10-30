# TikTok Business SDK يشير لمكتبة Google Play Billing لتتبع المشتريات داخل التطبيق،
# وتطبيقنا لا يبيع داخل التطبيق (الدفع عبر بوابة الويب)، فنتجاهل هذه الفئات.
-dontwarn com.android.billingclient.**
# الإبقاء على فئات TikTok Business SDK (تُستدعى عبر الانعكاس)
-keep class com.tiktok.** { *; }
-dontwarn com.tiktok.**
