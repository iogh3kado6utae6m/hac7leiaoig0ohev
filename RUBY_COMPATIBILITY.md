# Ruby Version Compatibility

Monitus supports multiple Ruby versions for running from sources.

## Supported Ruby Versions

- **Ruby 2.3.8** - Legacy support for older systems
- **Ruby 3.2+** - Modern Ruby versions (recommended)

## Running with Ruby 2.3.8

### Installation

```bash
cd src/
bundle install
```

### Starting the Application

**Option 1: Using rackup (if available)**
```bash
cd src/
rackup config.ru -p 4567
```

**Option 2: Using rack directly (Ruby 2.3.8)**
```bash
cd src/
ruby -r rack -e "Rack::Server.start(:config => 'config.ru', :Port => 4567)"
```

**Option 3: Using puma**
```bash
cd src/
bundle exec puma config.ru -p 4567
```

### Testing the Application

```bash
# Test basic endpoint
curl http://localhost:4567/monitus/metrics

# Test native prometheus endpoint
curl http://localhost:4567/monitus/passenger-status-native_prometheus
```

## Running with Ruby 3.2+

### Installation

```bash
cd src/
bundle install
```

### Starting the Application

```bash
cd src/
bundle exec rackup config.ru -p 4567
# or
bundle exec puma config.ru -p 4567
```

## Dependency Versions

| Gem | Ruby 2.3.8 | Ruby 3.2+ | Notes |
|-----|------------|-----------|-------|
| nokogiri | ~> 1.10.0 | Latest | Last version supporting Ruby 2.3.8 |
| sinatra | ~> 2.0.0 | Latest | Stable 2.x series |
| rack | ~> 2.0.0 | Latest | Core dependency |
| puma | ~> 3.12.0 | Latest | Last 3.x supporting Ruby 2.3.8 |
| rackup | N/A | Latest | Not available in Ruby 2.3.8 |

## Troubleshooting

### Ruby 2.3.8 Issues

**"rackup command not found"**
- Use alternative startup methods shown above
- rackup functionality is built into rack gem in Ruby 2.3.8

**Gem installation errors**
- Ensure you have development headers: `apt-get install ruby-dev`
- For nokogiri: `apt-get install libxml2-dev libxslt1-dev`

**"cannot load such file -- rackup"**
- This is expected in Ruby 2.3.8
- Use rack directly or puma as shown above

### Modern Ruby Issues

**"bundler: failed to load command: rackup"**
- Run: `bundle exec rackup` instead of just `rackup`
- Or: `gem install rackup` if not installed

## Development Notes

- The application code itself is compatible with both Ruby versions
- Only gem dependencies need version management
- Testing is primarily done on Ruby 3.2, but basic functionality works on 2.3.8
- For production, Ruby 3.2+ is recommended for security and performance

## Docker vs Source Installation

| Method | Ruby Version | Use Case |
|--------|--------------|----------|
| Docker | 3.2 (latest) | Production, CI/CD |
| Source | 2.3.8+ | Legacy systems, development |
| Source | 3.2+ | Modern development |
