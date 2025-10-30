# ValidationBot Security Setup (বাংলা গাইড)

## অপশন ১ — HashiCorp Vault ভিত্তিক নিরাপদ সিক্রেট ম্যানেজমেন্ট

Vault হলো তোমার সার্ভারের জন্য এনক্রিপ্টেড সিক্রেট স্টোর।
Spring Boot স্টার্টআপে Vault থেকে Oracle DB credentials, keystore password ইত্যাদি টেনে নেয়।

মূল ধাপগুলো:
1️⃣ Vault ইন্সটল ও কনফিগারেশন (TLS সহ)
2️⃣ Vault Init + Unseal + AppRole তৈরি
3️⃣ Oracle ডেটাবেসের ইউজার credential Vault-এ সংরক্ষণ
4️⃣ Spring Boot এর application.yml এ শুধু placeholder
5️⃣ Systemd unit এ ROLE_ID এবং SECRET_ID environment হিসেবে দেওয়া
6️⃣ Boot সময় Vault থেকে secret fetch করে অ্যাপ চালু হয়

সুবিধা: Full enterprise-grade security, audit trail, rotation, mTLS.


## অপশন ২ — SOPS + age (Vault ছাড়া Lightweight সিক্রেট এনক্রিপশন)

Vault না থাকলে, তুমি sops এবং age দিয়ে সিক্রেট ফাইল এনক্রিপ্ট করতে পারো।

কনসেপ্ট:
1️⃣ secrets.app.yaml ফাইলে DB পাসওয়ার্ডসহ সব সিক্রেট রাখো
2️⃣ sops --encrypt --age দিয়ে ফাইল এনক্রিপ্ট করো
3️⃣ systemd boot এ ফাইল decrypt হয়ে /run/valbot/app-secrets.yaml (RAM) এ লোড হবে
4️⃣ Spring Boot সেখানে থেকে config পড়ে নেবে
5️⃣ shutdown এ ফাইল shred হয়ে যাবে

systemd উদাহরণ:
ExecStartPre=/usr/bin/sops -d /opt/secrets/secrets.app.enc.yaml > /run/valbot/app-secrets.yaml
ExecStart=/usr/bin/java -jar /opt/valbot/validation-bot.jar
ExecStopPost=/bin/sh -c 'shred -u /run/valbot/app-secrets.yaml || true'

সুবিধা: Vault ছাড়া lightweight, zero static secret, on-prem friendly.


## Oracle DB Hardening

CREATE USER VALSVC IDENTIFIED BY "StrongPass123!";
GRANT CREATE SESSION TO VALSVC;
GRANT SELECT, INSERT, UPDATE ON VALIDATION_JOBS TO VALSVC;
GRANT SELECT, INSERT ON VALIDATION_ERRORS TO VALSVC;


## সিকিউরিটি চেকলিস্ট

✅ YAML বা কোডে কোনো static password না রাখা
✅ Oracle connection TLS বা wallet সহ ব্যবহার করা
✅ /etc/age/keys.txt permission 0400 রাখা
✅ tmpfs এ secret decrypt হওয়া এবং shutdown এ shred হওয়া
✅ password rotation ও audit trail চালু রাখা


## সারাংশ

🔹 HashiCorp Vault = Enterprise-level solution
🔹 SOPS + age = Lightweight, সহজ ও নিরাপদ
🔹 Oracle + Spring Boot = Secure integration through dynamic secret load


