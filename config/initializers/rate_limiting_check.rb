# frozen_string_literal: true

# The trusted proxies' IP addresses are *not* being used for user
# authentication; they're being used to counter CDN piercing and to
# ensure that our rate limits apply to the correct IP addresses.
Rails.application.config.after_initialize do
  middleware_classes = Rails.application.config.middleware.map(&:klass)
  remote_ip_idx = middleware_classes.index(ActionDispatch::RemoteIp)
  # Rack::Attack is added in config/application.rb
  rack_attack_idx = middleware_classes.index(Rack::Attack)

  if remote_ip_idx.nil? || rack_attack_idx.nil? || remote_ip_idx > rack_attack_idx
    SecurityUtils.security_assertion(
      false,
      'Security Configuration Error: RemoteIp must precede Rack::Attack in middleware stack.'
    )
  end
end
