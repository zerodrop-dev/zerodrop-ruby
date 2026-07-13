# frozen_string_literal: true

require_relative "lib/zerodrop/version"

Gem::Specification.new do |spec|
  spec.name = "zerodrop"
  spec.version = ZeroDrop::VERSION
  spec.authors = ["ZeroDrop"]
  spec.email = ["founder@zerodrop.dev"]

  spec.summary = "Disposable email inboxes for testing auth flows in CI — OTPs and magic links auto-extracted."
  spec.description = "ZeroDrop catches verification emails at Cloudflare's edge and auto-extracts " \
                     "OTP codes and magic links. Test email verification, magic links, OTP and " \
                     "password reset flows in RSpec, Minitest or Capybara — no regex, no Docker, no signup."
  spec.homepage = "https://zerodrop.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/zerodrop-dev/zerodrop-ruby"
  spec.metadata["documentation_uri"] = "https://docs.zerodrop.dev"
  spec.metadata["bug_tracker_uri"] = "https://github.com/zerodrop-dev/zerodrop-ruby/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]
end
