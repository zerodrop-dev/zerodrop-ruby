# zerodrop

[![Gem Version](https://badge.fury.io/rb/zerodrop.svg)](https://rubygems.org/gems/zerodrop)
[![CI](https://github.com/zerodrop-dev/zerodrop-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/zerodrop-dev/zerodrop-ruby/actions/workflows/ci.yml)
[![license](https://img.shields.io/github/license/zerodrop-dev/zerodrop-ruby.svg)](LICENSE)

Email verification infrastructure for CI pipelines.

Send a verification email. Catch it at the edge. Get `email.otp` and `email.magic_link` back — auto-extracted, no regex, no Docker, no signup to try.

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

Without a key, anyone who knows an inbox's name can read it, and one sender can reach only 5 different inboxes a day. With a free key, your inboxes start with your own prefix, only your key can read them, and mail to them isn't limited.

1. Sign in with GitHub at [zerodrop.dev/keys](https://zerodrop.dev/keys) and create a key.
2. Set it as `ZERODROP_API_KEY`. The client reads it automatically, or you can pass `api_key:`.

```ruby
mail = ZeroDrop::Client.new   # reads ZERODROP_API_KEY when it's set
mail.generate_inbox
# => "k7x2-swift-x7k29ab@zerodrop-sandbox.online", where k7x2 is your prefix
```

Reading a `k7x2-…` inbox without your key raises `ZeroDrop::AuthError` with the reason. Without a key, if ZeroDrop held an email because its sender passed the daily limit, the inbox gets a notice instead, and `fetch_latest` and `wait_for_latest` raise `ZeroDrop::HeldError` saying so (0.3.0 or later; older versions return the notice as if it were the email, or time out when a filter skips it). `mail.prefix` holds your prefix if you build an address yourself. A key holding a character that can't be sent in an HTTP header (a line break, a byte-order mark) makes `ZeroDrop::Client.new` raise `ArgumentError`; the message never includes the key.

## Workspace domain

A Workspace receives mail on a domain of its own, such as `yourcompany-qa.com`, so sign-up forms that block disposable domains accept it. Every inbox on it can be read only with your key. Set the domain as `ZERODROP_DOMAIN`, or pass `domain:`, next to your key:

```ruby
mail = ZeroDrop::Client.new(api_key: ENV["ZERODROP_API_KEY"], domain: "yourcompany-qa.com")
inbox = mail.generate_inbox
# => "k7x2-swift-x7k29ab@yourcompany-qa.com"
email = mail.wait_for_latest(inbox, timeout: 15)
```

Any address on the domain works, including one you name yourself: mail to `qa@yourcompany-qa.com` is filed under your prefix, and `mail.wait_for_latest("qa@yourcompany-qa.com")` reads it from there. `mail.domain` holds the domain in use. Workspaces are set up with the founder: [zerodrop.dev/pricing](https://zerodrop.dev/pricing).

## Parallel test runs

`generate_inbox` runs locally — no network request, no collisions:

```ruby
# parallel_tests, flatware, turbo_tests — all safe
# Each process gets isolated inboxes automatically
inbox = mail.generate_inbox # unique every call
```

Mail to many inboxes a day needs a free API key: without one, one sender can reach only 5 different inboxes a day.

## Error handling

```ruby
begin
  email = mail.wait_for_latest(inbox, timeout: 15)
rescue ZeroDrop::TimeoutError
  # No email arrived — check your app is sending correctly
rescue ZeroDrop::HeldError => e
  # Without an API key, the sender passed the daily limit (5 different inboxes a day) —
  # e.message says so; a free key from https://zerodrop.dev/keys lifts it
rescue ZeroDrop::AuthError => e
  # The inbox belongs to another key's prefix, or your key is wrong — e.message says which
rescue ZeroDrop::NetworkError => e
  # Transport failure — e.message includes status page link
end
```

## Workspaces

```ruby
mail = ZeroDrop::Client.new(api_key: ENV["ZERODROP_API_KEY"], domain: "yourcompany-qa.com")
```

## Self-hosted

```ruby
mail = ZeroDrop::Client.new(base_url: "https://your-instance.yourdomain.com")
```

## API

| Method | Description |
|---|---|
| `Client.new(api_key: nil, base_url: ..., domain: nil)` | Create a client. `api_key` defaults to `ENV["ZERODROP_API_KEY"]`; without a key, inboxes are public to anyone who knows the name. `domain` is your Workspace's own domain; it defaults to `ENV["ZERODROP_DOMAIN"]`, then the shared `zerodrop-sandbox.online`, and a value that isn't a domain name raises `ArgumentError`. |
| `#generate_inbox` | Instant inbox address. No network request. With a key, the name starts with your prefix. |
| `#prefix` | Your key's inbox prefix (`"k7x2"`), or `nil` without a key. |
| `#domain` | The domain generated addresses use: your Workspace's, or `zerodrop-sandbox.online`. |
| `#fetch_latest(inbox, filter: nil)` | Latest matching email or nil. Raises `HeldError` if nothing matches and the inbox has a notice that ZeroDrop held an email. |
| `#wait_for_latest(inbox, timeout: 10, poll_interval: 2, filter: nil)` | Block until email arrives. Raises `TimeoutError` on timeout, and `HeldError` at once if ZeroDrop held the email. |

## Free vs Workspace

|  | Free | Workspace |
|---|---|---|
| Inbox generation | ✓ | ✓ |
| OTP auto-extraction | ✓ | ✓ |
| Magic link extraction | ✓ | ✓ |
| Email filtering | ✓ | ✓ |
| Email retention | 30 min | Up to 7 days, set for your team |
| Custom domains | ✗ | ✓ (see [Workspace domain](#workspace-domain)) |
| API key | ✓ free at [zerodrop.dev/keys](https://zerodrop.dev/keys) | ✓ |
| Daily limit per sender | 5 inboxes without a key, none with one | None |

Get a Workspace at [zerodrop.dev](https://zerodrop.dev)

## License

MIT
