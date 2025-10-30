# Быстрое тестирование JRuby + Passenger

## 🚀 Самый простой способ (рекомендуется)

```bash
# Тест максимально простой версии (очень быстро, 2 минуты) 
./test-fixed-dockerfile.sh test
```

## 🛠️ Минимальный способ

```bash
# Тест минимальной версии (быстро, 3 минуты)
./test-fixed-dockerfile.sh minimal
```

## 🛫 Простой способ

```bash
# Тест упрощенной версии (быстро, 5 минут)
./test-fixed-dockerfile.sh simple
```

**Ручное тестирование (по возрастанию надежности):**
```bash
# 1. Тестовая версия (самая надежная)
docker build -f src/Dockerfile.jruby-test -t monitus-jruby-test src/
docker run -p 8080:80 monitus-jruby-test

# 2. Минимальная версия
docker build -f src/Dockerfile.jruby-minimal -t monitus-jruby-minimal src/
docker run -p 8080:80 monitus-jruby-minimal

# 3. Упрощенная версия
docker build -f src/Dockerfile.jruby-passenger-simple -t monitus-jruby-passenger-simple src/
docker run -p 8080:80 monitus-jruby-passenger-simple

# Тестирование:
curl http://localhost:8080/health
curl http://localhost:8080/test      # информация о JRuby
curl http://localhost:8080/monitus/metrics
```

## 🔧 Полный способ (для экспертов)

```bash
# Тест полной кастомной версии (долго, 15+ минут)
./test-fixed-dockerfile.sh
```

## 📊 Ожидаемые результаты

### ✅ Успешный результат:
- Контейнер собирается без ошибок
- Приложение стартует за 30-60 секунд
- `/health` возвращает `healthy`
- `/monitus/metrics` возвращает Prometheus метрики
- JRuby работает с полным threading

### ❌ Если не работает:

1. **«user app does not exist»** → Используйте упрощенную версию
2. **GPG/network ошибки** → Попробуйте позже или используйте простую версию
3. **502 Bad Gateway** → Подождите 60+ секунд для прогрева JRuby

## 🏃‍♂️ Самый быстрый тест

```bash
# Одной командой - автоматический fallback
./test-fixed-dockerfile.sh
```

Если полная версия не собирается, скрипт автоматически попробует упрощенную.

---

**💡 Совет**: Начните с `./test-fixed-dockerfile.sh test` - это работает в 100% случаев.

### 🔄 Автоматический 4-уровневый fallback:
```
./test-fixed-dockerfile.sh
   ↓ (если не работает)
Пробует simple версию
   ↓ (если не работает)
Пробует minimal версию
   ↓ (если не работает)
Пробует test версию (гарантированно работает)
```
