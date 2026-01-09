# Taksibu Backend

## Deployment (VPS)

Bu proje Docker Compose ile çalışır ve tüm ayarlarını `.env` dosyasından okur.

### 1. Kodları Güncelle
```bash
cd taksibu-backend
git pull origin main
```

### 2. .env Dosyasını Oluştur (ÇOK ÖNEMLİ)
Sunucuda `taksibu-backend` klasörünün içindeyken şu komutu çalıştırın: `nano .env`
Açılan ekrana **aşağıdaki kodların tamamını kopyalayıp yapıştırın**.

```properties
# --- Veritabanı Ayarları (VPS Mevcut Durum) ---
DB_HOST=127.0.0.1
DB_PORT=3306
DB_ROOT_PASSWORD=Polat.159357
DB_NAME=taksibu
DB_USER=root
# DİKKAT: Mevcut veritabanı şifresi budur, değiştirmeyin!
DB_PASSWORD=Polat.159357

# --- Redis Ayarları ---
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=redispass

# --- Uygulama Sırları (Değişmemeli) ---
JWT_SECRET=complex_jwt_secret_key_here
REFRESH_TOKEN_SECRET=complex_refresh_token_secret_here

# --- SMS Ayarları (MutluCell) ---
SMS_USERNAME=incigungor
SMS_PASSWORD=LKSArsAgMXxYW71n
SMS_ORG=902129233987

# --- Google Maps ---
GOOGLE_MAPS_API_KEY=AIzaSyAQlYbYijK5Nu2U-0WrL5qMPO1NN415A5Y

# --- Diğer ---
PORT=3000
NODE_ENV=production
RIDE_ACCEPT_TIMEOUT_SECONDS=30
LOG_LEVEL=info
```
*(Kaydetmek için: CTRL+O, Enter, ardından Çıkmak için: CTRL+X)*

### 3. Sistemi Başlat
```bash
sh deploy.sh
```
veya
```bash
docker-compose down
docker-compose up -d --build
```
