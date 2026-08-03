# ARM64를 지원하는 호환성 높은 Ubuntu 16.04 베이스 이미지 사용
FROM ubuntu:16.04

# 대화형 프롬프트 무시 및 운영 환경 설정
ENV DEBIAN_FRONTEND=noninteractive
ENV RAILS_ENV=production

# [추가] 시간대 및 Locale 환경 변수 설정
ENV TZ=Asia/Seoul
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 필수 패키지 설치 (locales 추가) 및 언어/시간대 세팅
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    locales \
    ruby \
    ruby-dev \
    build-essential \
    libmysqlclient-dev \
    libmagickwand-dev \
    imagemagick \
    tzdata \
    curl \
    git \
    apache2 php libapache2-mod-php php-mbstring php-gd php-curl php-xml php-mysql php-pgsql \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8 ko_KR.UTF-8 \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Redmine 3.2.1 소스코드 다운로드 및 압축 해제
WORKDIR /usr/src/redmine
RUN curl -L https://www.redmine.org/releases/redmine-3.2.1.tar.gz | tar -xz --strip-components=1

# 데이터베이스 연결 설정 (docker-compose.yml의 DB 정보와 일치시킴)
RUN echo "production:\n  adapter: mysql2\n  database: redmine\n  host: db\n  username: redmine\n  password: v9@Qm2#Lx7!Rz4$p\n  encoding: utf8mb4" > config/database.yml

# Bundler 설치 (Ruby 2.3 호환을 위해 구버전 1.x 설치)
RUN gem install bundler -v '~> 1.17' --no-ri --no-rdoc

# [핵심] 원본 Gemfile 기반 완벽 호환성 패치 적용
# 구버전 Ruby/Rails에서 문제를 일으키는 모든 Gem의 버전을 강제로 묶어둡니다.
RUN sed -i 's/gem "builder".*/gem "builder", ">= 3.0.4", "< 3.1.4"/' Gemfile && \
    sed -i 's/gem "nokogiri".*/gem "nokogiri", ">= 1.6.7.2", "< 1.10.0"/' Gemfile && \
    sed -i 's/gem "rails-html-sanitizer".*/gem "rails-html-sanitizer", ">= 1.0.3", "< 1.5.0"/' Gemfile && \
    echo "gem 'loofah', '< 2.20.0'" >> Gemfile && \
    echo "gem 'concurrent-ruby', '< 1.3.5'" >> Gemfile && \
    echo "gem 'i18n', '< 1.1.0'" >> Gemfile && \
    echo "gem 'rack', '< 2.0.0'" >> Gemfile && \
    echo "gem 'sprockets', '< 4.0.0'" >> Gemfile 

    # 의존성 Gem 설치 (개발 및 테스트 환경 제외)
RUN bundle install --without development test

# 세션 암호화 키 생성
RUN bundle exec rake generate_secret_token

# Apache2 프록시 모듈 활성화 + 가상호스트 설정
# - /ckfinder/* : PHP(CKFinder) 직접 서비스
# - 나머지 /*   : WEBrick(Redmine, :3000) 으로 역방향 프록시
RUN a2enmod proxy proxy_http && \
    echo '<VirtualHost *:80>\n\
    ServerName localhost\n\
\n\
    # CKFinder: PHP로 직접 서비스\n\
    Alias /ckfinder /var/www/html/ckfinder\n\
    <Directory /var/www/html/ckfinder>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
\n\
    # Redmine: WEBrick(:3000) 으로 역방향 프록시\n\
    ProxyPreserveHost On\n\
    ProxyPass /ckfinder !\n\
    ProxyPass / http://localhost:3000/\n\
    ProxyPassReverse / http://localhost:3000/\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

# 호스트와 연결할 볼륨 마운트 포인트 지정
VOLUME ["/usr/src/redmine/files", "/usr/src/redmine/plugins", "/usr/src/redmine/public/plugin_assets"]

# 포트 노출 (80만 외부 노출, 3000은 내부 전용)
EXPOSE 80

# 컨테이너 실행 시 Apache2 + Redmine(WEBrick) 동시 구동
CMD ["sh", "-c", "rm -f /var/run/apache2/apache2.pid && /usr/sbin/apache2ctl start && bundle install --without development test && bundle exec rake db:migrate RAILS_ENV=production && bundle exec rake redmine:plugins:migrate RAILS_ENV=production && bundle exec ruby bin/rails server webrick -e production -b 0.0.0.0"]

