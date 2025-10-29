# JRuby Support for Monitus

Monitus теперь поддерживает запуск на JRuby в Docker контейнерах, что обеспечивает лучшую производительность многопоточности и интеграцию с Java экосистемой.

## Обзор JRuby поддержки

### Преимущества JRuby

- **True Threading**: JRuby имеет настоящую многопоточность без Global Interpreter Lock (GIL)
- **JVM Performance**: Использует оптимизации JVM и JIT-компиляцию
- **Java Integration**: Прямой доступ к Java библиотекам и JVM метрикам
- **Memory Management**: Продвинутое управление памятью через JVM garbage collector
- **Scalability**: Лучшая масштабируемость для высоконагруженных систем

### Архитектура

```
┌──────────────┐
│   Monitus    │
│   on JRuby   │
├──────────────┤
│ Sinatra App │
├──────────────┤
│ JRuby 9.4+  │
├──────────────┤
│  JVM 17+    │
├──────────────┤
│  Puma       │
├──────────────┤
│ Passenger  │
└──────────────┘
```

## Быстрый старт

### 1. Standalone JRuby приложение

```bash
# Сборка JRuby Docker образа  
# Note: Uses vendor/bundle path instead of deployment mode for flexibility
docker build -f src/Dockerfile.jruby -t monitus-jruby src/

# Запуск
docker run -p 8080:8080 \
  -e JRUBY_OPTS="-Xcompile.invokedynamic=true" \
  -e JAVA_OPTS="-Xmx1G -Xms256M -XX:+UseG1GC" \
  monitus-jruby

# Проверка
curl http://localhost:8080/health
```

### 2. JRuby с Passenger

```bash
# Использование предготовленных конфигураций
cd test

# Запуск JRuby сервисов
make jruby-run

# Или через docker-compose напрямую
docker-compose -f docker-compose-jruby.yaml up
```

### 3. Тестирование JRuby поддержки

```bash
# Полное тестирование JRuby
cd test
make jruby-test

# Только сборка JRuby образов
make jruby-build

# Очистка JRuby ресурсов
make jruby-clean
```

## Конфигурация

### JRuby Environment Variables

```bash
# Оптимизация JRuby
export JRUBY_OPTS="-Xcompile.invokedynamic=true"

# JVM настройки
export JAVA_OPTS="-Xmx1G -Xms256M -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Приложение
export RACK_ENV=production
export PORT=8080
```

### Puma конфигурация для JRuby

Puma автоматически оптимизируется для JRuby в `src/config/puma.rb`:

```ruby
if defined?(JRUBY_VERSION)
  # Больше потоков для JRuby (true threading)
  threads 16, 32
  
  # Меньше воркеров (используем потоки)
  workers 1
  
  # Preload для лучшего использования памяти
  preload_app!
end
```

### Gemfile различия

- **MRI Ruby**: `src/Gemfile`
- **JRuby**: `src/Gemfile.jruby`

Основные отличия:
- Использует `jrjackson` вместо стандартного JSON
- Добавляет `jruby-openssl` для лучшего SSL
- Использует Java APIs для системных метрик
- Пропускает `thin` (использует Puma)

## Docker образы

### Доступные варианты

| Образ | Описание | Использование |
|-------|----------|---------------|
| `monitus-jruby-standalone` | Автономное JRuby приложение | Kubernetes, простое развертывание |
| `passenger-jruby-with-app` | JRuby + Passenger + dummy приложение | Тестирование с нагрузкой |
| `passenger-jruby-without-app` | JRuby + Passenger (только мониторинг) | Чистый мониторинг |

### Размеры образов

- **MRI Ruby образ**: ~150MB
- **JRuby образ**: ~400MB (включает JVM)

### Multi-stage сборка

```dockerfile
# Stage 1: Builder
FROM jruby:9.4 AS builder
# ... установка зависимостей

# Stage 2: Runtime
FROM jruby:9.4
# ... финальный образ
```

## Производительность

### Характеристики

| Метрика | MRI Ruby | JRuby | Преимущество JRuby |
|---------|----------|-------|--------------------|
| Startup time | ~2s | ~10s | ❌ Медленнее |
| Memory usage | ~50MB | ~200MB | ❌ Больше памяти |
| Request throughput | ~1000 req/s | ~3000 req/s | ✅ 3x быстрее |
| Concurrent requests | Limited (GIL) | Unlimited | ✅ True threading |
| JSON processing | Standard | JrJackson | ✅ 2x быстрее |

### Оптимизация производительности

1. **JVM tuning**:
   ```bash
   JAVA_OPTS="-Xmx1G -Xms256M -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
   ```

2. **JRuby optimizations**:
   ```bash
   JRUBY_OPTS="-Xcompile.invokedynamic=true"
   ```

3. **Warm-up period**:
   - JRuby требует время для JIT-компиляции
   - Первые запросы медленнее (~1-2s)
   - После прогрева производительность значительно выше

## Мониторинг JRuby

### JVM метрики

JRuby предоставляет дополнительные JVM метрики через Java APIs:

```ruby
if defined?(JRUBY_VERSION)
  require 'java'
  
  # Память JVM
  runtime = Java::JavaLang::Runtime.getRuntime
  total_memory = runtime.totalMemory
  free_memory = runtime.freeMemory
  used_memory = total_memory - free_memory
  
  # Информация о JVM
  java_version = Java::JavaLang::System.getProperty('java.version')
  jruby_version = JRUBY_VERSION
end
```

### Prometheus метрики

Дополнительные метрики для JRuby (можно добавить в prometheus_exporter.rb):

```
# JVM память
jruby_heap_memory_used_bytes{instance="default"}
jruby_heap_memory_total_bytes{instance="default"}
jruby_heap_memory_max_bytes{instance="default"}

# JVM информация  
jruby_runtime_info{java_version="11.0.28",jruby_version="9.4.14.0"}

# Потоки (available via standard Thread.list)
jruby_threads_active_count
```

## Troubleshooting

### Общие проблемы

#### 1. Медленный startup
```bash
# Решение: увеличьте health check период
HEALTHCHECK --start-period=60s
```

#### 2. OutOfMemoryError
```bash
# Решение: увеличьте heap size
JAVA_OPTS="-Xmx2G -Xms512M"
```

#### 3. Gem compatibility issues
```bash
# Проверьте JRuby совместимость
jruby -S gem list | grep problematic_gem

# Используйте Java альтернативы
# Например: jrjackson вместо oj
```

#### 4. SSL/TLS проблемы
```bash
# Убедитесь что jruby-openssl установлен
gem install jruby-openssl
```

#### 5. CI/CD версии JRuby
```bash
# Если версия недоступна в setup-ruby, используйте более старую:
# Проверить доступные версии:
# https://github.com/ruby/setup-ruby#supported-versions

# Обновить в .github/workflows/*.yml:
# ruby-version: jruby  # использует последнюю стабильную
# ruby-version: jruby-9.4.14.0  # или конкретную версию
# runs-on: ubuntu-22.04  # вместо ubuntu-latest для лучшей совместимости

# Многоуровневый fallback механизм в CI
```

### Логи и диагностика

```bash
# JRuby verbose режим
JRUBY_OPTS="--debug -X+C"

# JVM GC логи
JAVA_OPTS="-XX:+PrintGC -XX:+PrintGCDetails"

# Профилирование
JRUBY_OPTS="--profile.api"
```

### Performance Tuning

```bash
# Aggressive JIT compilation
JRUBY_OPTS="-Xcompile.invokedynamic=true -Xcompile.mode=JIT"

# Larger heap for high load
JAVA_OPTS="-Xmx4G -Xms1G -XX:+UseG1GC -XX:MaxGCPauseMillis=100"

# More file handles
ulimit -n 65536
```

## Развертывание

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitus-jruby
spec:
  replicas: 2
  selector:
    matchLabels:
      app: monitus-jruby
  template:
    metadata:
      labels:
        app: monitus-jruby
    spec:
      containers:
      - name: monitus
        image: monitus-jruby:latest
        ports:
        - containerPort: 8080
        env:
        - name: JRUBY_OPTS
          value: "-Xcompile.invokedynamic=true"
        - name: JAVA_OPTS
          value: "-Xmx1G -Xms256M -XX:+UseG1GC"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
```

### Docker Compose Production

```yaml
version: '3.8'
services:
  monitus-jruby:
    build:
      context: src
      dockerfile: Dockerfile.jruby
    ports:
      - "8080:8080"
    environment:
      - JRUBY_OPTS=-Xcompile.invokedynamic=true
      - JAVA_OPTS=-Xmx2G -Xms512M -XX:+UseG1GC -XX:MaxGCPauseMillis=200
      - RACK_ENV=production
    deploy:
      resources:
        limits:
          memory: 3G
          cpus: '2'
        reservations:
          memory: 1G
          cpus: '0.5'
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

## Сравнение с MRI Ruby

### Когда использовать JRuby

✅ **Используйте JRuby если**:
- Высокая нагрузка (>1000 req/s)
- Много параллельных запросов
- Интеграция с Java системами
- Долгоживущие процессы
- CPU-интенсивная обработка

❌ **Используйте MRI Ruby если**:
- Низкая нагрузка (<100 req/s)
- Ограниченная память (<512MB)
- Быстрый старт критичен
- Простое развертывание

### Migration checklist

- [ ] Проверить совместимость всех gems
- [ ] Обновить gem версии для JRuby
- [ ] Настроить JVM параметры
- [ ] Увеличить health check таймауты
- [ ] Протестировать под нагрузкой
- [ ] Настроить мониторинг JVM метрик
- [ ] Документировать JRuby-специфичные настройки

## Заключение

JRuby поддержка в Monitus предоставляет:

- **Лучшую производительность** для высоконагруженных систем
- **True threading** для параллельной обработки
- **JVM экосистему** для расширенных возможностей
- **Готовые Docker образы** для простого развертывания
- **Полную совместимость** с существующим кодом

Для большинства use cases MRI Ruby остается предпочтительным выбором из-за простоты и быстрого старта. JRuby рекомендуется для высоконагруженных production систем где производительность критична.
