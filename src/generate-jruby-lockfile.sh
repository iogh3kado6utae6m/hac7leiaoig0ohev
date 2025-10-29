#!/bin/bash
# Script to generate JRuby-specific Gemfile.lock
# This can be used if deployment mode is needed in the future

echo "Generating JRuby-specific Gemfile.lock..."

# Check if JRuby is available
if ! command -v jruby &> /dev/null; then
    echo "JRuby is not installed. Please install JRuby to generate JRuby-specific lockfile."
    exit 1
fi

# Backup existing lockfile if it exists
if [ -f Gemfile.lock ]; then
    cp Gemfile.lock Gemfile.lock.backup
    echo "Backed up existing Gemfile.lock to Gemfile.lock.backup"
fi

# Use JRuby Gemfile
cp Gemfile.jruby Gemfile.temp
cp Gemfile Gemfile.mri.backup

# Generate lockfile with JRuby
cp Gemfile.temp Gemfile
jruby -S bundle install
mv Gemfile.lock Gemfile.jruby.lock

# Restore original files
mv Gemfile.mri.backup Gemfile
rm Gemfile.temp

echo "JRuby lockfile generated as Gemfile.jruby.lock"
echo "To use deployment mode in Dockerfile.jruby, add:"
echo "COPY Gemfile.jruby.lock Gemfile.lock"
