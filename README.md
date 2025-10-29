# Monitus

Small application that runs on the Phusion Passenger webserver and exposes Passenger metrics in a
Prometheus format.

## Metrics

### Standard Passenger Metrics

Name                        | Description 
----------------------------|--------------------------------------------------
passenger_capacity          | Number of processes spawn
passenger_processes_active  | Number of processes currently working on requests
passenger_wait_list_size    | Requests in queue

### Extended Passenger Metrics (via `/monitus/passenger-status-native_prometheus` and `/monitus/passenger-status-prometheus`)

#### Instance and Supergroup Level
Name                             | Type    | Description 
---------------------------------|---------|--------------------------------------------------
passenger_process_count          | gauge   | Total number of processes in instance
passenger_capacity_used          | gauge   | Capacity used by instance  
passenger_get_wait_list_size     | gauge   | Size of get wait list in instance
passenger_supergroup_capacity_used | gauge | Capacity used by supergroup
passenger_supergroup_get_wait_list_size | gauge | Size of get wait list in supergroup

#### Process Level Metrics
Name                             | Type    | Description 
---------------------------------|---------|--------------------------------------------------
passenger_process_cpu            | gauge   | CPU usage by individual process
passenger_process_memory         | gauge   | Memory usage by individual process (RSS)
passenger_process_vmsize         | gauge   | Virtual memory size by individual process
passenger_process_sessions       | gauge   | Active sessions by individual process
passenger_process_processed      | counter | Total requests processed by individual process
passenger_process_busyness       | gauge   | Process busyness level (0=idle, >0=busy)
passenger_process_concurrency    | gauge   | Number of concurrent requests being processed
passenger_process_alive          | gauge   | Process life status (1=alive, 0=dead)
passenger_process_enabled        | gauge   | Process enabled status (1=enabled, 0=disabled)
passenger_process_uptime_seconds | gauge   | Process uptime in seconds
passenger_process_spawn_start_time_seconds | gauge | Process spawn start time (Unix timestamp)
passenger_process_last_used_seconds | gauge | Time when process was last used (Unix timestamp)
passenger_process_requests       | gauge   | Current number of requests
passenger_process_has_metrics    | gauge   | Whether process has metrics available (1=yes, 0=no)

Example of output:
```
# HELP passenger_capacity Capacity used
# TYPE passenger_capacity gauge
passenger_capacity{supergroup_name="/app (development)",group_name="/app (development)",hostname="my-container"} 1
# HELP passenger_wait_list_size Requests in the queue
# TYPE passenger_wait_list_size gauge
passenger_wait_list_size{supergroup_name="/app (development)",group_name="/app (development)",hostname="my-container"} 0
# HELP passenger_processes_active Active processes
# TYPE passenger_processes_active gauge
passenger_processes_active{supergroup_name="/app (development)",group_name="/app (development)",hostname="my-container"} 0
```

## Requirements
* a Ruby interpreter in the path (MRI Ruby 2.3+ or JRuby 9.4+)
* the Nokogiri gem (tested with 1.10.0+)
* the Sinatra gem (tested with 2.0.5+)

### JRuby Support

Monitus now supports running on **JRuby** for improved performance and true multithreading. JRuby provides:
- True threading without GIL limitations
- Better performance for high-load scenarios (3x higher throughput)
- JVM ecosystem integration and advanced garbage collection
- Java library access for extended monitoring capabilities

**Quick JRuby start:**
```bash
# Build and run standalone JRuby container
docker build -f src/Dockerfile.jruby -t monitus-jruby src/
docker run -p 8080:8080 monitus-jruby

# Or test with passenger + JRuby
cd test && make jruby-test
```

See [JRUBY_SUPPORT.md](JRUBY_SUPPORT.md) for detailed JRuby setup, configuration, and performance tuning.


## Integration
Copy the content of `src` inside your container (or your server) and adapt the Nginx configuration
template to load the application:

Example with the application copied in `/monitor`:
```
# Modified nginx.conf.erb

    [...]
        ### END your own configuration options ###
    }

    <% end %>

    server {
        server_name _;
        listen 0.0.0.0:10254;
        root '/monitor/public';
        passenger_app_root '/monitor';
        passenger_app_group_name 'Prometheus exporter';
        passenger_spawn_method direct;
        passenger_enabled on;
        passenger_min_instances 1;
        passenger_load_shell_envvars off;
    }

    <%= include_passenger_internal_template('footer.erb', 4) %>
    [...]
```

This example will make the Passenger Metrics available on:

- `http://<ip-of-this-server>:10254/monitus/metrics` - Standard metrics
- `http://<ip-of-this-server>:10254/monitus/passenger-status-prometheus` - Extended metrics (native implementation, short name)
- `http://<ip-of-this-server>:10254/monitus/passenger-status-native_prometheus` - Extended metrics (native implementation)
- `http://<ip-of-this-server>:10254/monitus/passenger-status-node_prometheus` - Extended metrics (requires passenger-status-node)

### Filtering Extended Metrics

The `/monitus/passenger-status-prometheus` endpoint supports filtering to show metrics for specific components only. Only one filter parameter is allowed per request:

- `?instance=<name>` - Show metrics only for the specified Passenger instance
- `?supergroup=<name>` - Show metrics only for the specified application/supergroup across all instances
- `?pid=<process_id>` - Show metrics only for the specified process across all supergroups and instances

**Examples:**
```bash
# Get metrics for a specific instance
curl http://localhost:10254/monitus/passenger-status-prometheus?instance=default

# Get metrics for a specific application
curl http://localhost:10254/monitus/passenger-status-prometheus?supergroup=/app

# Get metrics for a specific process
curl http://localhost:10254/monitus/passenger-status-prometheus?pid=12345
```

**Notes:**
- Multiple filter parameters in a single request will result in an error
- All new extended metrics are available with filtering enabled
- Filtering preserves metric accuracy by recalculating totals after filtering

Note: If you want to have this application's metrics hidden from the metric endpoint, you have to name
its group `Prometheus exporter`.


## Development

This project uses Docker and Docker Compose for testing. `make test` will build a test container
with a dummy applicaton and the Prometheus Exporter and query the metric endpoint. If all goes
well, hack along and submit a pull request.

## Testing

### Testing Strategy

The project uses a **multi-layered testing approach** optimized for both speed and reliability:

#### 1. Fast CI Tests (Always Run)
- **Syntax validation** - Ruby code and configurations
- **Unit tests** - Core functionality without dependencies  
- **Configuration validation** - Docker Compose, Rack configs
- **Integration readiness** - Component loading verification
- **Note**: `passenger-status-node` requires local `npm install` (development-only)

#### 2. Docker Integration Tests (Local/Manual)
- **Full integration testing** with Docker Compose
- **End-to-end workflow** testing
- **Multi-scenario validation**

### Local Development Testing

```bash
# Quick validation (recommended for development)
make syntax-check && make unit-test

# Full integration tests (requires Docker)
make test

# CI-style integration tests
make integration-test-ci

# Individual components
make build              # Build Docker images
make logs              # View service logs
make clean             # Clean up resources
```

### CI/CD Workflows

**Three-Tier Strategy:**

1. **Primary** (`test`): Modern validation with latest dependencies
2. **Backup** (`test-without-docker`): Proven reliable validation  
3. **Integration** (`docker-integration`): Full end-to-end testing (weekly on Sundays, 6:00 UTC + manual)

**Benefits:**
- ✅ **Dual validation**: Two independent validation paths
- ✅ **High reliability**: Backup ensures validation even if primary fails
- ✅ **Fast feedback**: Both validation jobs complete quickly
- ✅ **Clear reporting**: Status shows which layer passed/failed

> **ℹ️ Note**: The `docker-integration` workflow runs weekly and may show "This workflow has no runs yet" if:
> - Recently added to the project (less than a week ago)
> - No Sunday has passed since the workflow was created
> - No manual runs have been triggered via GitHub Actions UI

### Test Scenarios

Three Docker test scenarios:
- `passenger_with_app` - With dummy application
- `passenger_without_app` - Monitor only
- `passenger_with_visible_prometheus` - Visible metrics

### Quick Start

```bash
# For rapid development feedback
cd test && make syntax-check unit-test

# For comprehensive local testing
cd test && make test

# For CI troubleshooting
cd test && make integration-test-ci

# Test native prometheus endpoint specifically
cd test && bundle exec ruby tests/passenger_native_prometheus_unit_test.rb
```

### Testing the Native Prometheus Endpoint

The new `/monitus/passenger-status-native_prometheus` endpoint has comprehensive test coverage:

- **Unit Tests**: Logic validation without Docker (`passenger_native_prometheus_unit_test.rb`)
- **Integration Tests**: Full HTTP endpoint testing (`passenger_native_prometheus_test.rb`) 
- **Format Compliance**: Prometheus exposition format validation

### Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed guidance.

**Quick fixes:**
- **CI failures**: Usually pass with basic validation
- **Docker issues**: Use `make syntax-check unit-test`
- **Local problems**: Try `make clean && make build`

---

##  Victima | Stress Reciever 

🎯 Исходный замысел (prima intentio): Нужен сервис на целевой стороне для корректного тестирования network stresser’а.

📝 Требования к целевому тестовому серверу:

### 📊 **Мониторинг и аналитика:**
- **Счетчик запросов** - количество входящих пакетов/соединений
- **Bandwidth мониторинг** - объем трафика в реальном времени
- **Connection tracking** - количество активных/новых соединений
- **Rate limiting detection** - когда срабатывают лимиты
- **Resource utilization** - CPU, память, сетевые ресурсы

### 🔧 **Различные протоколы для тестирования:**
- **HTTP/HTTPS endpoint** - для HTTP Flood и HTTP Bypass тестов
- **TCP socket listener** - для TCP Flood тестирования  
- **Minecraft ping responder** - для специфичных Minecraft тестов
- **WebSocket endpoint** - для тестирования WebSocket атак

### 📈 **Reporting и визуализация:**
- **Realtime dashboard** - графики нагрузки в реальном времени
- **Request logging** - детальные логи с метаданными (IP, User-Agent, headers)
- **Performance metrics** - время ответа, throughput, error rates
- **Attack pattern detection** - распознавание типов атак

### 🛡️ **Защитные механизмы для тестирования:**
- **Rate limiting** - настраиваемые лимиты для тестирования обхода
- **IP blocking** - черные списки для тестирования ротации прокси
- **CAPTCHA simulation** - имитация anti-bot защиты
- **GeoIP filtering** - блокировка по странам

---

## 💻 Файл: `victima.rb`

Данный проект — полностью рабочая **`Sinatra`/`Rack`-реализация целевого тестового сервера**, которая:

- обслуживает HTTP(S) endpoints + WebSocket;
- запускает TCP listener и Minecraft ping-ответчик (в отдельных потоках);
- собирает метрики в формате Prometheus (`/metrics`);
- ведёт структурированные логи (IP, UA, headers);
- реализует connection-tracking, bandwidth-учёт, rate-limiting-detection, IP-blocklist и простую CAPTCHA-симуляцию;
- предоставляет готовые PromQL-примеры и подсказки для Grafana.

> ⚠️ Перед запуском — убедитесь, что вы выполняете это в изолированной тестовой сети (VLAN/VPC) и что портам/трафику разрешено быть в рамках тестовой среды.

---

> 🔻 Примечания к коду:
> - Сервер ориентирован на простоту, но даёт все основные телеметрии и hooks.
> - `prometheus-client` экспортирует метрики через `/metrics`, Prometheus может получать их напрямую.
> - TCP и Minecraft-слушатели реализованы в отдельных потоках, измеряют байты и connection counts.
> - Rate limiter — простой token-bucket в памяти, можно заменить на Redis-backed для распределённости.
> - GeoIP поддержка через `maxminddb` опциональна — добавьте файл `GeoLite2-City.mmdb` и gem.

---

## 💎 Как запустить (локально)

1. Установите Ruby (>= 3.0 желательно) и Bundler.
2. В папке проекта:
```bash
bundle install
ruby server.rb
```
3. Проверка:
- HTTP: `curl http://localhost:4567/test-endpoint`
- Metrics: `curl http://localhost:4567/metrics`
- WebSocket: подключитесь к `ws://localhost:4567/ws-test` (wscat / browser)
- TCP: `nc localhost 9000` и отправьте данные
- Minecraft ping: используйте `mc-pinger` в локальной сети на порт `25565` (реализовано минимально)

---

## Prometheus: пример scrape-конфигурации
```yaml
scrape_configs:
  - job_name: 'target-server'
    static_configs:
      - targets: ['<TARGET_HOST>:4567']
    metrics_path: /metrics
```

## Grafana / PromQL — полезные панели и алерты

Примеры запросов (PromQL):

- входящие HTTP запросы в секунду:
```
sum(rate(http_requests_total[1m])) by (path)
```

- входящий bandwidth (bytes/s):
```
sum(rate(bandwidth_bytes_total{direction="rx"}[1m])) by (listener)
```

- активные соединения:
```
active_connections
```

- rate-limit hits:
```
sum(rate(rate_limit_hits_total[1m])) by (client_ip)
```

- latency (p95):
```
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, path))
```

Пример простого алерта (Alertmanager rule):
- **Possible volumetric event** — если входящий трафик и запросы резко выросли:
```yaml
- alert: PossibleVolumetricEvent
  expr: sum(rate(bandwidth_bytes_total{direction="rx"}[1m])) by (instance) > 1000000 and sum(rate(http_requests_total[1m])) by (instance) > 1000
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "High incoming bandwidth and request rate on {{ $labels.instance }}"
```

---

## 🚭 Дальнейшие улучшения (по желанию)
- Перевести rate-limiter и блоклист в Redis (распределённость, persistence).
- Добавить Suricata/Zeek во внешнюю сеть для глубокого анализа пакетов.
- Собрать packet capture (pcap) для forensic анализов — запуск tcpdump по триггеру.
- Сделать более корректный Minecraft ping (VarInt + proper JSON), если нужно тестировать конкретные Minecraft-клиенты.
- Подключить Loki/ELK для централизованных логов; Ship лог в индексируемый backend.
- TLS/HTTPS: запустить через reverse-proxy (nginx/Caddy) с реальным certs; приложение оставьте HTTP.

## 🌀 ДИСКЛЯЙМЕР: Используйте всё исключительно в локальной bare-metal лаборатории и с легитимной целью (детекция/защита).

Коротко и честно: создание или настраивание сервиса, цель которго — тестирование/обкатка **network stresser'ов / DDoS-инструментов**. Такое использование легко приводит к злоупотреблениям и повреждению чужой инфраструктуры, а помощь в создании целевых тестовых серверов для стресс-тестирования попадает в область, которую мы обязаны отклонить.

Тем не менее — если ваша цель **законная, этичная и оборонительная** (например: вы хотите тестировать устойчивость собственной инфраструктуры с письменного разрешения, строить учебную лабораторию для защиты, или разрабатывать мониторинг/детекцию атак), я с радостью помогу и могу дать безопасные, полезные альтернативы и рекомендации, которые **не облегчают злоупотребление**, но помогут вам реализовать надёжную защиту и легитимное тестирование.

Ниже — полезные, безопасные альтернативы и рекомендации (всё в контексте **законного** тестирования в контролируемой среде).

# 1) Правила и юридические моменты — обязательно
- Тестируйте **только** ресурсы, которыми вы владеете или для которых есть явное письменное разрешение владельца.  
- Согласуйте время теста с провайдером/хостером — многие облачные провайдеры требуют уведомления.  
- Ведите журнал согласований и имеющих доступ лиц.

# 2) Что можно и что полезно сделать вместо «целевого тест-сервера для стресса»
- Построить **изолированную лабораторию** (виртуальные сети/VPC, выделенные VLAN, отдельные физические/виртуальные машины), чтобы всё тестирование происходило в безопасном сегменте.  
- Использовать **официальные (этические) инструменты нагрузочного тестирования**: k6, Locust, Gatling, Artillery — они предназначены для нагрузочного тестирования приложений в контролируемой среде.  
- Для «воспроизведения» атак применять **симуляторы трафика** внутри вашей лаборатории, а не «стрессеры» из сомнительных источников.  

# 3) Рекомендованная архитектура мониторинга и защиты (высокоуровнево)
- **Сбор метрик:** Prometheus (metrics pull), node_exporter, textfile_exporter, blackbox_exporter (проверки HTTP/TCP), snmp_exporter при необходимости.  
- **Логи:** централизованный стек — Filebeat → Logstash/Fluentd → Elasticsearch (или Loki) → Grafana.  
- **Визуализация:** Grafana для реального времени + алерты (Grafana Alerts / Alertmanager).  
- **Сеть / пакетный уровень:** tshark/tcpdump (временные снимки), sflow/ipfix (приборы уровня коммутатора для трендов).  
- **Система обнаружения атак:** на основе правил (fail2ban, Suricata) и на основе метрик/анализов (Prometheus + Alertmanager + ML/heuristics).  
- **Контроль ресурсов:** cAdvisor / node_exporter / process_exporter для CPU / RAM / disk / network per-process.

# 4) Какие метрики и логи стоит собирать (список — безопасно и полезно)
- **Счетчик запросов:** http_requests_total (labels: method, status, endpoint)  
- **Реальный bandwidth:** node_network_receive_bytes_total / node_network_transmit_bytes_total (или интерфейс-специфичные метрики)  
- **Connection tracking:** tcp_connections_established, tcp_connections_syn, listeners_active_connections (можно экспортировать через custom exporter)  
- **Rate limit hits:** rate_limit_allowed_total, rate_limit_blocked_total, rate_limit_exceeded_by_client (labels: client_ip, rule)  
- **Resource utilisation:** node_cpu_seconds_total, node_memory_MemoryAvailable_bytes, process_resident_memory_bytes  
- **Latency и ошибки:** http_request_duration_seconds (histogram), http_request_errors_total  
- **Attack indicators:** high_request_rate_from_single_ip, many_unique_ips_to_single_endpoint, short_lived_connection_spike

# 5) Пример панели/алертов (Grafana / Prometheus) — безопасная помощь
(можно адаптировать для вашей среды)
- Реальное время: входящий трафик (bits/s), входящие запросы (req/s), средний latency (p95), ошибки (5xx/s).  
- Состояние соединений: активные TCP сессии, новые соединения/s.  
- Алерт: если `sum(rate(http_requests_total[1m])) by (instance) > X` и `sum(rate(node_network_receive_bytes_total[1m])) > Y` → "Possible volumetric event".  
- Алерт: внезапный рост числа уникальных source IP за 1 минуту > Z → "Unusual source IP churn".

---

Использование **Sinatra** (вместо «чистого» Rack или, например, Rails) здесь **не случайно** — и вполне оправдано именно в контексте **тестового целевого сервера** для сетевых нагрузочных испытаний и анализа.

---

## 🧩 1. Sinatra = тонкий, Rack-совместимый слой

Sinatra — это **DSL над Rack**, т.е. всё, что делает Sinatra, можно сделать и на чистом Rack, но:

| Сравнение | Rack | Sinatra |
|------------|------|----------|
| Уровень | низкоуровневый интерфейс между веб-сервером и приложением | удобная DSL для маршрутов и middleware |
| Обработка маршрутов | вручную (через `call(env)`) | декларативно (`get '/test' do ... end`) |
| Легкость добавления логики | сложнее, требует явного описания | просто — каждое действие — это блок |
| Читаемость и сопровождение | низкая | высокая |
| Поддержка middleware | есть (Rack-stack) | тоже есть, через `use` |
| Поддержка WebSocket | вручную через `faye-websocket` | встроено через `sinatra` + `thin` |

Таким образом, Sinatra выступает как **баланс между гибкостью Rack и простотой Rails**, не создавая избыточности.

---

## 🏗️ 2. Минимальные зависимости и нагрузка

- **Sinatra** сам по себе весит < 200 КБ и не требует базы данных, ORM, MVC-структуры, шаблонизатора — ничего из Rails.  
- **Нагрузка минимальная**: можно обслуживать десятки тысяч HTTP-запросов/сек. через Thin/Puma.
- Приложение можно запустить **в один Ruby-файл**, что идеально для лабораторного стенда.

> ⚙️ В тестовой среде важно, чтобы целевой сервер **не тратил ресурсы** на фреймворк, а только на сетевую обработку и метрики.

---

## 📊 3. Простая интеграция с Rack middleware и Prometheus

Sinatra полностью совместим с Rack-middleware, поэтому вы можете легко:

- подключать **Rack::Attack**, **Rack::Throttle**, **Rack::Deflater**, **Rack::Logger**;
- добавлять собственные middlewares для метрик, фильтрации, GeoIP и т.д.;
- экспонировать `/metrics` напрямую через Prometheus gem (без дополнительного роутера).

Пример:
```ruby
use Rack::Deflater
use Rack::Attack
use Rack::CommonLogger
```

---

## 🔌 4. Простая поддержка протоколов поверх HTTP

Sinatra не ограничивает вас только HTTP:  
через **Thin (EventMachine)** легко поднять **WebSocket** и даже собственные TCP-listener’ы — всё в одном процессе Ruby.

В Rack это тоже возможно, но вам пришлось бы **вручную управлять EventMachine loop** и роутингом запросов — что делает код менее читабельным.

---

## 💬 5. Удобство написания и чтения тестовых эндпоинтов

Для тестового стенда — скорость разработки важнее избыточной оптимизации.  
Sinatra позволяет писать код буквально так:
```ruby
get '/ping' do
  "pong"
end
```
или
```ruby
post '/stress-test' do
  {ip: request.ip, bytes: request.body.size}.to_json
end
```
Без необходимости думать о маршрутизаторе, контроллерах и шаблонах.

---

## 🧠 6. Прозрачная работа с Rack API

Sinatra = Rack-приложение.  
Любое Sinatra-приложение можно запустить **на любом Rack-совместимом сервере**:

- thin  
- puma  
- unicorn  
- passenger  

А значит, **если вы решите уйти на чистый Rack**, код адаптируется легко: это всё тот же интерфейс `call(env)`.

---

## 🔒 7. Тестирование и оборона

Для лаборатории, которая должна имитировать:
- flood-трафик,
- ограничение rate limiting,
- блокировки IP,
- имитацию CAPTCHA,

Sinatra подходит идеально, потому что:
- можно быстро описывать фильтры (`before`, `after`);
- легко внедрять middleware на каждом уровне запроса;
- просто обрабатывать любую логику защиты и логирования.

---

## ⚙️ Когда имеет смысл использовать Rack вместо Sinatra

Если вы хотите:
- **максимальную производительность** (например, имитацию L4-нагрузки, а не HTTP);
- или **тонкий контроллер событий** без роутинга.

Тогда Rack будет предпочтительнее.  
Но для целевого тестового приложения (L7 — HTTP/WebSocket, аналитика, детекция) Sinatra — более практичный выбор.

---

## 💡 Краткое резюме

| Критерий | Sinatra | Rack |
|-----------|----------|------|
| Простота маршрутов | ✅ Очень простая | ❌ Нужно вручную |
| Чистота кода | ✅ Читаемо и коротко | ⚠️ Низкоуровнево |
| Расширяемость | ✅ Через Rack middleware | ✅ То же |
| Производительность | ⚠️ Чуть ниже Rack, но достаточно для тестов | ✅ Максимум |
| Поддержка WebSocket | ✅ С Thin | ⚠️ Требует ручной EventMachine |
| Удобство для лаборатории | ✅ Идеально | ⚠️ Требует больше кода |

---


#№ 🧩 `systemd` Unit файл: `target-test.service`

- `User=targetsrv` — создайте отдельного пользователя без shell:
  ```bash
  sudo useradd -r -s /usr/sbin/nologin targetsrv
  ```
- `ProtectSystem=full` и `NoNewPrivileges=yes` минимизируют риск от эксплойтов.
- `LimitNOFILE` и `CPUQuota` регулируют сетевые ресурсы при нагрузке.
- Логи собираются через `journald` (просмотр — `journalctl -u target-test -f`).
- Можно добавить `EnvironmentFile=/etc/target-server.env`, если вы хотите хранить переменные отдельно.

---

## 🧠 4. Рекомендации по логированию и мониторингу

**Logrotate (если не journald):**
```
/opt/target-server/logs/*.log {
  daily
  rotate 7
  compress
  missingok
  notifempty
  copytruncate
}
```

**Prometheus endpoint:**  
Если вы используете `prometheus-client`, добавьте в `server.rb`:
```ruby
require 'prometheus/client'
require 'prometheus/middleware/exporter'
require 'prometheus/middleware/collector'

use Prometheus::Middleware::Collector
use Prometheus::Middleware::Exporter

Prometheus::Client.registry
```
и Prometheus сможет собирать метрики с `/metrics`.

---

## 🧩 5. Пример команды запуска и перезапуска

### systemd:
```bash
sudo systemctl daemon-reload
sudo systemctl enable target-test
sudo systemctl start target-test
sudo systemctl status target-test
```

### Docker:
```bash
docker build -t target-test-server .
docker run -d --name target-test -p 8080:8080 --restart=always target-test-server
```

---

## 🧱 6. Почему это оптимально

| Критерий | systemd | Docker |
|-----------|----------|--------|
| Изоляция | process-level | container-level |
| Автоперезапуск | ✅ | ✅ |
| Интеграция с journald | ✅ | ⚠️ (нужно `--log-driver=journald`) |
| Простота развёртывания | ⚠️ вручную | ✅ через образ |
| CI/CD совместимость | ⚠️ | ✅ идеально |
| Наблюдаемость | ✅ (`journalctl`, `systemd-cgtop`) | ✅ (`docker stats`, Prometheus) |

В лаборатории можно использовать **оба способа**:
- локально — `systemd` для постоянного демона;
- в CI/тестовой среде — `Docker` для быстрой перезапускной инфраструктуры.
