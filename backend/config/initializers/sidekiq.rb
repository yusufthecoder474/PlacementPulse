# Sidekiq (Redis-backed) configuration.
# In the test environment the Active Job adapter is overridden to :test
# (see config/environments/test.rb), so specs never touch a real Redis queue.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
