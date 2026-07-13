# zerodrop

[![Gem Version](https://badge.fury.io/rb/zerodrop.svg)](https://rubygems.org/gems/zerodrop)
[![CI](https://github.com/zerodrop-dev/zerodrop-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/zerodrop-dev/zerodrop-ruby/actions/workflows/ci.yml)
[![license](https://img.shields.io/github/license/zerodrop-dev/zerodrop-ruby.svg)](LICENSE)

Email verification infrastructure for CI pipelines.

Send a verification email. Catch it at the edge. Get `email.otp` and `email.magic_link` back — auto-extracted, no regex, no Docker, no signup.

```ruby
email = mail.wait_for_latest(inbox, timeout: 15)

email.otp        # => "123456" — auto-extracted
email.magic_link # => "https://..." — no regex needed
```

**[Documentation](https://docs.zerodrop.dev)** · [GitHub](https://github.com/zerodrop-dev) · [Status](https://zerodrop.instatus.com)

## Install

```bash
gem install zerodrop
```

Or in your Gemfile:

```ruby
gem "zerodrop", group: :test
```

Zero runtime dependencies. Ruby 3.0+.

## Quick start

```ruby
require "zerodrop"

mail = ZeroDrop::Client.new
inbox = mail.generate_inbox
# => "swift-x7k29ab@zerodrop-sandbox.online"

# Trigger your app's email flow with the inbox address...

email = mail.wait_for_latest(inbox, timeout: 15)

email.subject    # => "Verify your email"
email.otp        # => "123456" — auto-extracted, no regex
email.magic_link # => "https://..." — auto-extracted
```

## RSpec + Capybara

```ruby
RSpec.describe "Signup email verification", type: :system do
  let(:mail) { ZeroDrop::Client.new }

  it "verifies the account via emailed OTP" do
    inbox = mail.generate_inbox

    visit "/signup"
    fill_in "Email", with: inbox
    fill_in "Password", with: "TestPassword123!"
    click_button "Create account"

    email = mail.wait_for_latest(inbox, timeout: 15)

    expect(email.otp).not_to be_nil
    fill_in "Code", with: email.otp
    click_button "Verify"

    expect(page).to have_current_path("/dashboard")
  end
end
```

## Minitest

```ruby
require "minitest/autorun"
require "zerodrop"

class SignupTest < Minitest::Test
  def test_email_verification
    mail = ZeroDrop::Client.new
    inbox = mail.generate_inbox

    # Trigger signup with inbox...

    email = mail.wait_for_latest(inbox, timeout: 15)

    refute_nil email.otp
    assert_match(/\A\d{6}\z/, email.otp)
  end
end
```

## Email filtering

Filter by sender, subject, body, or extracted fields:

```ruby
email = mail.wait_for_latest(
  inbox,
  timeout: 15,
  filter: ZeroDrop::Filter.new(
    from: "noreply@yourapp.com",
    subject: "Verify",
    has_otp: true
  )
)
```

All string filters are case-insensitive partial matches.

## Magic link flows

```ruby
email = mail.wait_for_latest(
  inbox,
  timeout: 15,
  filter: ZeroDrop::Filter.new(has_magic_link: true)
)

visit email.magic_link
expect(page).to have_current_path("/dashboard")
```

## Parallel test runs

`generate_inbox` runs locally — no network request, no collisions:

```ruby
# parallel_tests, flatware, turbo_tests — all safe
# Each process gets isolated inboxes automatically
inbox = mail.generate_inbox # unique every call
```

## Error handling

```ruby
begin
  email = mail.wait_for_latest(inbox, timeout: 15)
rescue ZeroDrop::TimeoutError
  # No email arrived — check your app is sending correctly
rescue ZeroDrop::AuthError
  # Invalid API key
rescue ZeroDrop::NetworkError => e
  # Transport failure — e.message includes status page link
end
```

## Workspaces

```ruby
mail = ZeroDrop::Client.new(api_key: ENV["ZERODROP_API_KEY"])
```

## Self-hosted

```ruby
mail = ZeroDrop::Client.new(base_url: "https://your-instance.yourdomain.com")
```

## API

| Method | Description |
|---|---|
| `Client.new(api_key: nil, base_url: ...)` | Create a client. No args = free sandbox mode. |
| `#generate_inbox` | Instant inbox address. No network request. |
| `#fetch_latest(inbox, filter: nil)` | Latest matching email or nil. |
| `#wait_for_latest(inbox, timeout: 10, poll_interval: 2, filter: nil)` | Block until email arrives. |

## Free vs Workspace

|  | Free | Workspace |
|---|---|---|
| Inbox generation | ✓ | ✓ |
| OTP auto-extraction | ✓ | ✓ |
| Magic link extraction | ✓ | ✓ |
| Email filtering | ✓ | ✓ |
| Email retention | 30 min | Extended |
| Custom domains | ✗ | ✓ |

Get a Workspace at [zerodrop.dev](https://zerodrop.dev)

## License

MIT
