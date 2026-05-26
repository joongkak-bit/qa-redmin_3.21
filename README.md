# Redmine Docker 환경

Redmine 3.2.1 을 Docker Compose 로 구동하는 프로젝트입니다.  
Apache2 가 리버스 프록시 역할을 하며, CKFinder(PHP) 와 Redmine(WEBrick) 을 함께 서비스합니다.

---

## 구성도

```
┌──────────────────────────────────────────────────────────────┐
│                        Host (호스트 서버)                    │
│                                                              │
│   ./files/     ./plugins/   ./plugin_assets/   ./ckfinder/   │
│      │              │              │                │        │
└──────┼──────────────┼──────────────┼────────────────┼────────┘
       │ (볼륨 마운트) │              │                │
┌──────┼──────────────┼──────────────┼────────────────┼───────────────────────┐
│      ▼              ▼              ▼                ▼   redmine_app         │
│  /usr/src/      /usr/src/      /usr/src/      /var/www/    (Ubuntu 16.04)   │
│  redmine/       redmine/       redmine/       html/                         │
│  files/         plugins/       public/        ckfinder/                     │
│                                plugin_assets/                               │
│                                                                             │
│  ┌───────────────────────────────────────────────────────┐                  │
│  │                  Apache2  (포트 80)                   │   ← 외부 접근    │
│  │                                                       │                  │
│  │   /ckfinder/*  ──────────→  PHP (CKFinder)            │                  │
│  │   /*           ──────────→  ProxyPass                 │                  │
│  └──────────────────────────────────┬────────────────────┘                  │
│                                     │                                       │
│  ┌──────────────────────────────────▼────────────────────┐                  │
│  │           WEBrick (포트 3000, 내부 전용)               │                 │
│  │           Redmine 3.2.1  (Rails production)           │                  │
│  └──────────────────────────────────┬────────────────────┘                  │
└─────────────────────────────────────┼───────────────────────────────────────┘
                                      │ MySQL2  (host: db)
┌─────────────────────────────────────▼───────────────────────────────────────┐
│  redmine_db  (MariaDB 10.3)                                                 │
│  DB: redmine  /  User: redmine                                              │
│  데이터 볼륨: redmine_db_data → /var/lib/mysql                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 서비스 구성

| 서비스 | 컨테이너명 | 이미지 | 역할 |
|--------|-----------|--------|------|
| `redmine` | `redmine_app` | Ubuntu 16.04 (커스텀 빌드) | Apache2 + WEBrick + CKFinder |
| `db` | `redmine_db` | MariaDB 10.3 | Redmine 데이터베이스 |

### 포트

| 포트 | 설명 |
|------|------|
| `80` | 외부 접근 (Apache2) |
| `3000` | 내부 전용 (WEBrick, 컨테이너 내부) |

### 볼륨 마운트

| 호스트 경로 | 컨테이너 경로 | 설명 |
|------------|--------------|------|
| `./files/` | `/usr/src/redmine/files` | 첨부파일 (연도별 폴더, git 제외) |
| `./plugins/` | `/usr/src/redmine/plugins` | Redmine 플러그인 |
| `./plugin_assets/` | `/usr/src/redmine/public/plugin_assets` | 플러그인 정적 자산 |
| `./ckfinder/` | `/var/www/html/ckfinder` | CKFinder 파일 관리자 |

---

## 시작 방법

### 1. 사전 요구사항

- Docker Engine 20.x 이상
- Docker Compose 1.29 이상

### 2. 최초 실행 (이미지 빌드 포함)

```bash
docker-compose up -d --build
```

최초 실행 시 아래 작업이 자동으로 수행됩니다.

1. Ubuntu 16.04 기반 이미지 빌드 (Ruby, Apache2, PHP 등 설치)
2. Redmine 3.2.1 소스 다운로드 및 Gem 설치
3. DB 마이그레이션 (`rake db:migrate`)
4. 플러그인 마이그레이션 (`rake redmine:plugins:migrate`)
5. Apache2 + WEBrick 동시 구동

> 최초 빌드는 네트워크 환경에 따라 **10~20분** 소요될 수 있습니다.

### 3. 구동 확인

```bash
docker-compose ps
```

두 컨테이너가 모두 `Up` 상태이면 정상입니다.

```
Name              Command               State          Ports
-----------------------------------------------------------------
redmine_app   sh -c rm -f /var/run ...   Up      0.0.0.0:80->80/tcp
redmine_db    docker-entrypoint.sh ...   Up      3306/tcp
```

### 4. 브라우저 접속

```
http://서버IP
```

- 기본 관리자 계정: `admin` / `admin`  
  (최초 로그인 후 즉시 비밀번호 변경 권장)

### 5. CKFinder 접속

```
http://서버IP/ckfinder/ckfinder.html
```

---

## 이후 실행 (이미지 재빌드 없이)

```bash
docker-compose up -d
```

---

## 중지 및 재시작

```bash
# 중지
docker-compose stop

# 재시작
docker-compose start

# 컨테이너 삭제 (데이터 볼륨은 유지)
docker-compose down
```

---

## 로그 확인

```bash
# 전체 로그
docker-compose logs -f

# Redmine 앱만
docker-compose logs -f redmine

# DB만
docker-compose logs -f db
```

---

## git 제외 항목 (.gitignore)

| 경로 | 이유 |
|------|------|
| `files/20*/` | 연도별 첨부파일 (용량 큼, 서버 보관) |
| `ckfinder/userfiles/images/` | 업로드 이미지 (이미지 서버 보관) |
