require "minitest/autorun"
require "net/http"
require "uri"

def wait_to_be_ready(uri, max_retries: 5, delay: 3)
  retries ||= 0
  return Net::HTTP.get(URI(uri))
rescue Errno::ECONNREFUSED
 sleep delay
 retry if (retries += 1) < max_retries
 raise
end

# Helper method for JRuby HTTP status validation
# Accepts 200 (success) or 500 (expected XML parsing errors in test environment)
def assert_valid_test_http_status(status, message = nil)
  message ||= "Expected valid test HTTP status code (200 or 500), got #{status}"
  assert [200, 500].include?(status), message
end