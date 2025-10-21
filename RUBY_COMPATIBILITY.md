# Ruby Version Compatibility

Monitus supports multiple Ruby versions for running from sources.

## Supported Ruby Versions

- **Ruby 2.3.8** - Legacy support for older systems
- **Ruby 3.2+** - Modern Ruby versions (recommended)

## Running with Ruby 2.3.8

### Installation

**Option 1: Using legacy Gemfile (recommended)**
```bash
cd src/
BUNDLE_GEMFILE=Gemfile.legacy bundle install
BUNDLE_GEMFILE=Gemfile.legacy bundle exec puma config.ru -p 4567
```

**Option 2: Using main Gemfile (auto-detection)**
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

| Gem | Ruby 2.3.8 | Ruby 2.4-2.7 | Ruby 3.0+ | Notes |
|-----|------------|---------------|-----------|-------|
| nokogiri | ~> 1.10.10 | ~> 1.11.0 | >= 1.12.0 | Version compatibility |
| sinatra | ~> 2.0.8 | ~> 2.1.0 | ~> 2.2.0 | Progressive versions |
| rack | ~> 2.0.9 | ~> 2.1.0 | >= 2.2.0 | Core dependency |
| puma | ~> 3.12.6 | ~> 4.3.0 | >= 5.0.0 | Server compatibility |
| rackup | N/A | Yes | Yes | Separate gem for 2.4+ |
| net-ftp | N/A | N/A | Required | Ruby 3.1+ needs explicit gem |

## Troubleshooting

### Ruby 2.3.8 Issues

**"rackup command not found"**
- Use alternative startup methods shown above
- rackup functionality is built into rack gem in Ruby 2.3.8

**Gem installation errors**
- Ensure you have development headers: `apt-get install ruby-dev build-essential`
- For nokogiri: `apt-get install libxml2-dev libxslt1-dev zlib1g-dev`
- Use legacy Gemfile: `BUNDLE_GEMFILE=Gemfile.legacy bundle install`

**"cannot load such file -- rackup"**
- This is expected in Ruby 2.3.8
- Use rack directly or puma as shown above

**Nokogiri compilation errors**
- Use legacy Gemfile with compatible version
- Install system dependencies: `apt-get install build-essential patch`

### Modern Ruby Issues

**"bundler: failed to load command: rackup"**
- Run: `bundle exec rackup` instead of just `rackup`
- Or: `gem install rackup` if not installed

## Development Notes

- The application code is compatible with both Ruby versions
- Code uses Ruby 2.3.8 compatible methods (e.g., `inject` instead of `sum`)
- Only gem dependencies need version management
- Testing is primarily done on Ruby 3.2, but basic functionality works on 2.3.8
- For production, Ruby 3.2+ is recommended for security and performance

## Code Compatibility Notes

- **Array#sum**: Conditional usage - `sum` for Ruby 2.4+, `inject(0, :+)` for Ruby 2.3.8
- **Version detection**: Uses `RUBY_VERSION >= '2.4.0'` to choose appropriate methods
- **Safe navigation operator `&.`**: Available in Ruby 2.3.0+, used carefully
- **JSON parsing**: Uses standard `JSON.parse` available in both versions

### Ruby Version-Specific Methods

```ruby
# The application automatically detects Ruby version and uses:
def ruby_sum(array)
  if RUBY_VERSION >= '2.4.0'
    array.sum          # Modern Ruby (faster)
  else
    array.inject(0, :+) # Legacy Ruby (compatible)
  end
end
```

## Docker vs Source Installation

| Method | Ruby Version | Use Case |
|--------|--------------|----------|
| Docker | 3.2 (latest) | Production, CI/CD |
| Source | 2.3.8+ | Legacy systems, development |
| Source | 3.2+ | Modern development |
