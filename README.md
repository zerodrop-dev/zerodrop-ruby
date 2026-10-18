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

## Free API key (private inboxes)

Without a key, anyone who knows an inbox's name can read it. With a free key, your inboxes start with your own prefix and only your key can read them.

1. Sign in with GitHub at [zerodrop.dev/keys](https://zerodrop.dev/keys) and create a key.
2. Set it as `ZERODROP_API_KEY`. The client reads it automatically, or you can pass `api_key:`.

```ruby
mail = ZeroDrop::Client.new   # reads ZERODROP_API_KEY when it's set
mail.generate_inbox
# => "k7x2-swift-x7k29ab@zerodrop-sandbox.online", where k7x2 is your prefix
```

Reading a `k7x2-…` inbox without your key raises `ZeroDrop::AuthError` with the reason. `mail.prefix` holds your prefix if you build an address yourself. A key holding a character that can't be sent in an HTTP header (a line break, a byte-order mark) makes `ZeroDrop::Client.new` raise `ArgumentError`; the message never includes the key.

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
rescue ZeroDrop::AuthError => e
  # The inbox belongs to another key's prefix, or your key is wrong — e.message says which
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
| `Client.new(api_key: nil, base_url: ...)` | Create a client. `api_key` defaults to `ENV["ZERODROP_API_KEY"]`; without a key, inboxes are public to anyone who knows the name. |
| `#generate_inbox` | Instant inbox address. No network request. With a key, the name starts with your prefix. |
| `#prefix` | Your key's inbox prefix (`"k7x2"`), or `nil` without a key. |
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
| API key | ✓ free at [zerodrop.dev/keys](https://zerodrop.dev/keys) | ✓ |

Get a Workspace at [zerodrop.dev](https://zerodrop.dev)

## License

MIT
