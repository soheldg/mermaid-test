# 🧩 অপশন ২ — Vault না থাকলেও প্রায় সমান নিরাপদ (SOPS + age Lightweight Setup)

## 🎯 উদ্দেশ্য
Spring Boot অ্যাপে কোনো পাসওয়ার্ড বা ডাটাবেজ তথ্য `application.yml`-এ থাকবে না।  
তুমি সব সিক্রেট এক ফাইলে এনক্রিপ্ট করে রাখবে (`secrets.app.enc.yaml`),  
আর system boot-এর সময় **স্বয়ংক্রিয়ভাবে decrypt হবে RAM (tmpfs)**-এ,  
Spring Boot সেটার data ব্যবহার করবে,  
shutdown-এর সময় RAM-ফাইল shred হয়ে যাবে 🔥।

---

## 🧰 ধাপ ১: SOPS এবং age ইনস্টল করা
**Ubuntu / Debian এর জন্য:**
```bash
sudo apt update
sudo apt install -y age
sudo wget https://github.com/mozilla/sops/releases/download/v3.8.1/sops_3.8.1_amd64.deb
sudo apt install ./sops_3.8.1_amd64.deb
```
**চেক করো ইনস্টল হয়েছে কিনা:**
```bash
sops --version
age --version
```

---

## 🔑 ধাপ ২: age কী তৈরি (একবারই করতে হয়)
```bash
sudo mkdir -p /etc/age
sudo age-keygen -o /etc/age/keys.txt
sudo chmod 0400 /etc/age/keys.txt
```
**Public key দেখো:**  
```bash
# public key: age1hv5r6tghz8zv...
```
এই public key দিয়ে secret ফাইল encrypt করা হবে।

---

## 📦 ধাপ ৩: তোমার সিক্রেট YAML তৈরি করা
`/opt/secrets/secrets.app.yaml` ফাইল তৈরি করো:
```yaml
spring:
  datasource:
    driver-class-name: oracle.jdbc.OracleDriver
    url: jdbc:oracle:thin:@//10.10.10.5:1521/PROD
    username: VALSVC
    password: StrongPass123!
  hikari:
    maximum-pool-size: 10
    connection-timeout: 20000
keystore:
  pass: changeit
```

---

## 🔐 ধাপ ৪: ফাইল এনক্রিপ্ট করা
Public key ধরো: `age1hv5r6tghz8zv...`
```bash
sops --encrypt --age age1hv5r6tghz8zv... /opt/secrets/secrets.app.yaml > /opt/secrets/secrets.app.enc.yaml
```
এখন plaintext ফাইল মুছে দাও:
```bash
shred -u /opt/secrets/secrets.app.yaml
```
✅ `/opt/secrets/secrets.app.enc.yaml` এখন **encrypted version**, নিরাপদে Git বা সার্ভারে রাখা যাবে।

---

## ⚙️ ধাপ ৫: Spring Boot কনফিগারেশন
`application.yml`-এ কেবল placeholder রাখো:
```yaml
spring:
  config:
    import: optional:file:/run/valbot/app-secrets.yaml

spring:
  datasource:
    url: ${spring.datasource.url}
    username: ${spring.datasource.username}
    password: ${spring.datasource.password}
```
Spring Boot startup এ `/run/valbot/app-secrets.yaml` থেকে ডেটা টেনে নেবে।

---

## 🧠 ধাপ ৬: systemd সার্ভিস ফাইল তৈরি
`/etc/systemd/system/valbot.service` ফাইলটি এমন হবে:
```ini
[Unit]
Description=Validation Bot (SOPS-secure)
Requires=network-online.target
After=network-online.target

[Service]
User=valbot
Group=valbot
Environment=SOPS_AGE_KEY_FILE=/etc/age/keys.txt

ExecStartPre=/bin/mkdir -p /run/valbot && /bin/mount -t tmpfs tmpfs /run/valbot
ExecStartPre=/usr/bin/sops -d /opt/secrets/secrets.app.enc.yaml > /run/valbot/app-secrets.yaml
Environment=SPRING_CONFIG_IMPORT=file:/run/valbot/app-secrets.yaml
ExecStart=/usr/bin/java -jar /opt/valbot/validation-bot.jar
ExecStopPost=/bin/sh -c 'shred -u /run/valbot/app-secrets.yaml || true'

Restart=always
RestartSec=5
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/opt/valbot
ReadWritePaths=/run/valbot /var/log/valbot

[Install]
WantedBy=multi-user.target
```
👉 boot-এর সময় secret ফাইল decrypt হয়ে RAM এ তৈরি হবে, shutdown-এর সময় shred হবে।

---

## 🔎 ধাপ ৭: সার্ভিস চালানো
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now valbot
sudo systemctl status valbot
journalctl -u valbot -f
```

---

## 🧱 ধাপ ৮: Oracle সাইড কনফিগারেশন
```sql
CREATE USER VALSVC IDENTIFIED BY "StrongPass123!";
GRANT CREATE SESSION TO VALSVC;
GRANT SELECT, INSERT, UPDATE ON VALIDATION_JOBS TO VALSVC;
GRANT SELECT, INSERT ON VALIDATION_ERRORS TO VALSVC;
```

---

## ⚠️ নিরাপত্তা পরামর্শ
| বিষয় | পরামর্শ |
|------|----------|
| 🔐 keys.txt | `/etc/age/keys.txt` permission 0400, owner root |
| 🔥 tmpfs | `/run/valbot` RAM storage, reboot হলে auto delete |
| 💣 Git | `.enc.yaml` ছাড়া অন্য secret কখনো commit করো না |
| 🕒 rotation | Oracle password বদলালে নতুন `.enc.yaml` encrypt করে replace করো |
| 🔍 audit | `journalctl -u valbot`-এ কোনো plaintext leak নেই তা যাচাই করো |

---

## ✅ সারাংশ
| ধাপ | কাজ |
|-----|-----|
| ১ | `age` ও `sops` ইনস্টল |
| ২ | `/etc/age/keys.txt` তৈরি |
| ৩ | `secrets.app.yaml` ফাইল encrypt |
| ৪ | `application.yml` এ placeholder |
| ৫ | `systemd` unit কনফিগার |
| ৬ | Boot এ decrypt → RAM → অ্যাপ পড়ে |
| ৭ | Shutdown এ shred |

---

## 🔚 Bottom Line
Vault না থাকলেও,  
এই পদ্ধতিতে তুমি পুরো সিস্টেমকে প্রায় Vault-এর মতো নিরাপদ করে ফেলবে।  
সব সিক্রেট থাকবে এনক্রিপ্টেড অবস্থায়, ডিক্রিপ্ট হবে শুধু RAM-এ,  
shutdown-এর সাথে সেগুলো মুছে যাবে।  
এটাই হলো **on-prem lightweight zero-static-secret architecture** 🔐🚀
