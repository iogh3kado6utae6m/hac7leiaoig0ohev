# Быстрое тестирование JRuby + Passenger

## 🚀 Простой способ (рекомендуется)

```bash
# Тест упрощенной версии (быстро, 5 минут)
./test-fixed-dockerfile.sh simple
```

**Или вручную:**
```bash
docker build -f src/Dockerfile.jruby-passenger-simple -t monitus-jruby-passenger-simple src/
docker run -p 8080:80 monitus-jruby-passenger-simple

# В другом терминале:
curl http://localhost:8080/health
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

**💡 Совет**: Начните с `./test-fixed-dockerfile.sh simple` - это работает в 99% случаев.
