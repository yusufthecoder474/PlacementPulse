# CORS: only the configured frontend origin may call this API from a browser.
# Defaults to the Vite dev server origin used by the PlacementPulse frontend.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173")
    resource "*",
             headers: :any,
             methods: %i[get post patch put delete options head],
             expose: %w[Authorization]
  end
end
