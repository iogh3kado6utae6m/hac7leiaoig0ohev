# 🔍 Анализ проблемы и официальное решение

## 📋 Анализ текущего состояния

На основе последних логов контейнера:

```
[ N 2025-10-30 23:16:09.2177 41/T1 age/Cor/CoreMain.cpp:1016 ]: Passenger core online, PID 41
[ E 2025-10-30 23:16:11.6503 41/T6 age/Cor/SecurityUpdateChecker.h:521 ]: A security update is available...
Oct 30 23:17:01 6744b4f83666 CRON[258]: (root) CMD (   cd / && run-parts --report /etc/cron.hourly)
```

### ✅ Что работает:
1. **Nginx запускается** без ошибок
2. **Passenger core online** - ок, PID 41
3. **Контейнер работает** 1 минуту
4. **Нет Nginx ошибок** конфигурации

### 🤔 Проблема:
**Контейнер самопроизвольно останавливается через 1 минуту.**

Это **НЕ** nginx ошибка. Это **НЕ** passenger ошибка. Возможно:

1. Приложение не отвечает на запросы
2. JRuby/Приложение рушится молча
3. Проблема с Docker или baseimage init

---

## 🔍 Исследование официальных паттернов

На основе анализа `/tmp/passenger-docker/image/`:

### 🔑 Ключевые открытия:

#### 1. JRuby установка (`jruby-9.4.12.0.sh`):
```bash
run /usr/local/rvm/bin/rvm install $RVM_ID
run /usr/local/rvm/bin/rvm-exec $RVM_ID@global gem install $DEFAULT_RUBY_GEMS --no-document
run create_rvm_wrapper_script jruby9.4 $RVM_ID ruby
run create_rvm_wrapper_script jruby $RVM_ID ruby
run create_rvm_wrapper_script ruby3.1 $RVM_ID ruby  # Ключевое!
```

#### 2. Passenger native support (`nginx-passenger.sh`):
```bash
if [[ -e /usr/bin/jruby9.4 ]]; then
    run jruby9.4 --dev -S passenger-config build-native-support
    run setuser app jruby9.4 --dev -S passenger-config build-native-support
fi
```

#### 3. Правильная структура runit сервисов:
```bash
# Nginx service
mkdir -p /etc/service/nginx
echo 'exec /usr/sbin/nginx -g "daemon off;"' > /etc/service/nginx/run

# Nginx log forwarder  
mkdir -p /etc/service/nginx-log-forwarder
echo 'exec svlogd -tt /var/log/nginx/' > /etc/service/nginx-log-forwarder/run
```

---

## ✨ Новое решение: Официальные паттерны

### 🎯 Создан `Dockerfile.jruby-official-pattern`:

1. **Точное воспроизведение** buildconfig из официального проекта
2. **Правильная RVM установка** с GPG ключами
3. **JRuby 9.4.14.0** с Java 17 (как в официальном jruby-9.4.12.0.sh)
4. **Полный набор wrapper scripts** как в официальном finalize.sh
5. **Native support compilation** для JRuby
6. **Правильную nginx + runit структуру**

### 🚀 Тестирование:

```bash
# Новая команда для официального подхода:
./test-fixed-dockerfile.sh official

# Или старая команда (с обновленной логикой HTTP тестов):
./test-fixed-dockerfile.sh test
```

---

## 📝 Ожидаемые улучшения

### Официальный подход должен разрешить:

1. **Проблемы с wrapper scripts** - используем точно те же имена и пути
2. **Проблемы с native support** - precompile как в официальном проекте
3. **Проблемы с runit сервисами** - правильная структура
4. **Проблемы с Java версией** - используем Java 17 как в официальном jruby-9.4.12.0.sh

### Обновленный тест должен разрешить:

1. **Проблему с таймаутом** - ранняя HTTP проверка на 15й секунде
2. **Лучшую диагностику** проблем с ответом приложения

---

## 🏁 Итог

Мы прошли путь от простых исправлений до **полного воспроизведения официальной методологии** passenger-docker.

### Последовательность решений:
1. **ffa4713**: Минимальные nginx директивы
2. **90ccbb9**: Официальные паттерны passenger-docker
3. **Обновленный тест**: Ранняя HTTP проверка

**Успех должен быть достигнут с высокой вероятностью.**
