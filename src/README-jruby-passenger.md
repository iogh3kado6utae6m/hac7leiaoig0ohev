# Обновлено: Исправленная конфигурация JRuby + Passenger

**⚠️ Важное обновление**: Конфигурация была исправлена на основе изучения официального проекта Passenger Docker.

## Ключевые улучшения:

✅ **RVM интеграция**: Теперь используется RVM для управления JRuby вместо ручной установки  
✅ **Wrapper скрипты**: Созданы правильные wrapper скрипты в `/usr/bin/` для системной интеграции  
✅ **Passenger нативная поддержка**: Предкомпилированы нативные расширения Passenger для JRuby  
✅ **Runit система**: Использует стандартную систему инициализации Passenger вместо самописных скриптов  
✅ **Улучшенная обработка ошибок**: Более надежная обработка сбоев при запуске  

---

# JRuby + Phusion Passenger + Nginx Docker Setup

Этот Dockerfile создает высокопроизводительный production-ready образ с JRuby, работающим через Phusion Passenger в качестве модуля Nginx.

## 🚀 Особенности

- **JRuby 9.4.14.0** с оптимизациями для production
- **Phusion Passenger** как application server
- **Nginx** как web server и reverse proxy
- **Оптимизированная конфигурация** для JRuby threading
- **Автоматический health check** и мониторинг
- **Graceful shutdown** и restart

## 🏗️ Сборка образа

```bash
# Сборка JRuby + Passenger образа
docker build -f src/Dockerfile.jruby-passenger -t monitus-jruby-passenger src/
```

## 🎯 Запуск контейнера

### Базовый запуск

```bash
docker run -p 80:80 monitus-jruby-passenger
```

### Запуск с настройками производительности

```bash
docker run -p 80:80 \
  -e JRUBY_OPTS="-Xcompile.invokedynamic=true" \
  -e JAVA_OPTS="-Xmx2G -Xms512M -XX:+UseG1GC" \
  -e PASSENGER_MIN_INSTANCES=3 \
  -e PASSENGER_MAX_INSTANCES=12 \
  -e PASSENGER_THREAD_COUNT=20 \
  monitus-jruby-passenger
```

### Production запуск с Docker Compose

```yaml
version: '3.8'
services:
  jruby-passenger:
    build:
      context: ./src
      dockerfile: Dockerfile.jruby-passenger
    ports:
      - "80:80"
    environment:
      - RACK_ENV=production
      - JRUBY_OPTS=-Xcompile.invokedynamic=true
      - JAVA_OPTS=-Xmx2G -Xms512M -XX:+UseG1GC -XX:MaxGCPauseMillis=200
      - PASSENGER_MIN_INSTANCES=3
      - PASSENGER_MAX_INSTANCES=12
      - PASSENGER_THREAD_COUNT=20
      - PASSENGER_CONCURRENCY_MODEL=thread
    volumes:
      - ./logs:/var/log/webapp
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

## ⚙️ Переменные окружения

### JRuby конфигурация

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `JRUBY_OPTS` | `-Xcompile.invokedynamic=true -J-Djnr.ffi.asm.enabled=false` | JRuby оптимизации |
| `JAVA_OPTS` | `-Xmx1G -Xms256M -XX:+UseG1GC -XX:MaxGCPauseMillis=200` | JVM параметры |
| `RACK_ENV` | `production` | Rack окружение |

### Passenger конфигурация

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `PASSENGER_MIN_INSTANCES` | `2` | Минимальное количество процессов |
| `PASSENGER_MAX_INSTANCES` | `8` | Максимальное количество процессов |
| `PASSENGER_THREAD_COUNT` | `16` | Количество потоков на процесс |
| `PASSENGER_CONCURRENCY_MODEL` | `thread` | Модель concurrency (thread/process) |
| `PASSENGER_APP_ENV` | `production` | Passenger окружение |

## 🔍 Endpoints

### Health Check

```bash
# Nginx health (быстрый)
curl http://localhost:80/nginx-health
# Ответ: "Nginx OK"

# Application health (через приложение)
curl http://localhost:80/health  
# Ответ: "OK - JRuby 9.4.14.0"

# Информация о сервере
curl http://localhost:80/info
# JSON с информацией о JRuby, Passenger, etc.
```

### Metrics (если доступны)

```bash
# Prometheus metrics
curl http://localhost:80/metrics
```

## 📊 Мониторинг и логи

### Логи

```bash
# Nginx access logs
docker exec <container> tail -f /var/log/nginx/webapp_access.log

# Nginx error logs
docker exec <container> tail -f /var/log/nginx/webapp_error.log

# Application logs
docker logs <container>
```

### Passenger статус

```bash
# Информация о Passenger процессах
docker exec <container> passenger-status

# Использование памяти
docker exec <container> passenger-memory-stats
```

## 🔧 Настройка производительности

### Для высокой нагрузки

```bash
docker run -p 80:80 \
  -e JAVA_OPTS="-Xmx4G -Xms1G -XX:+UseG1GC -XX:MaxGCPauseMillis=100" \
  -e PASSENGER_MIN_INSTANCES=4 \
  -e PASSENGER_MAX_INSTANCES=16 \
  -e PASSENGER_THREAD_COUNT=32 \
  --memory=6g \
  --cpus=4 \
  monitus-jruby-passenger
```

### Для экономии ресурсов

```bash
docker run -p 80:80 \
  -e JAVA_OPTS="-Xmx512M -Xms128M -XX:+UseSerialGC" \
  -e PASSENGER_MIN_INSTANCES=1 \
  -e PASSENGER_MAX_INSTANCES=3 \
  -e PASSENGER_THREAD_COUNT=8 \
  --memory=1g \
  --cpus=1 \
  monitus-jruby-passenger
```

## 🐛 Отладка

### Проверка конфигурации

```bash
# Тест Nginx конфигурации
docker exec <container> nginx -t

# Проверка Passenger
docker exec <container> passenger-config validate-install

# JRuby информация
docker exec <container> jruby --version
docker exec <container> java -version
```

### Интерактивная сессия

```bash
# Войти в контейнер
docker exec -it <container> bash

# JRuby REPL
docker exec -it <container> jruby -e "require 'java'; puts JRUBY_VERSION"
```

## ⚡ Преимущества JRuby + Passenger

- **True threading** - JRuby позволяет использовать истинные потоки Java
- **Лучшая производительность** - JVM оптимизации и JIT компиляция
- **Стабильность** - Passenger обеспечивает надежное управление процессами
- **Масштабируемость** - Эффективное использование многоядерных систем
- **Production-ready** - Проверенная комбинация для высоконагруженных систем

## 🔄 Сравнение с Puma

| Характеристика | JRuby + Passenger | JRuby + Puma |
|----------------|------------------|---------------|
| **Process management** | Автоматическое (Passenger) | Ручное |
| **Memory usage** | Лучше (shared memory) | Выше |
| **Thread safety** | Отличная | Хорошая |
| **Restart strategy** | Graceful rolling restart | Manual restart |
| **Nginx integration** | Нативная | Через upstream |
| **Production readiness** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## 📝 Примеры использования

См. также:
- [docker-compose-jruby-passenger.yml](../test/docker-compose-jruby-passenger.yml)
- [Kubernetes deployment example](../k8s/jruby-passenger-deployment.yaml)