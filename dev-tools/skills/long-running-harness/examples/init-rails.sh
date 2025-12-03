#!/bin/bash
# =============================================================================
# init.sh for Ruby on Rails projects
# Purpose: Setup environment so agent can start working immediately
# =============================================================================
set -e

echo "🔧 Setting up Ruby on Rails environment..."

# -----------------------------------------------------------------------------
# 1. Check Ruby version
# -----------------------------------------------------------------------------
if command -v ruby &> /dev/null; then
    echo "✅ Ruby $(ruby -v | cut -d' ' -f2)"
else
    echo "❌ Ruby not found. Please install Ruby first."
    exit 1
fi

# Check if using correct Ruby version
if [ -f ".ruby-version" ]; then
    EXPECTED_VERSION=$(cat .ruby-version)
    CURRENT_VERSION=$(ruby -v | cut -d' ' -f2 | cut -d'p' -f1)
    if [[ "$CURRENT_VERSION" != "$EXPECTED_VERSION"* ]]; then
        echo "⚠️ Expected Ruby $EXPECTED_VERSION, got $CURRENT_VERSION"
    fi
fi

# -----------------------------------------------------------------------------
# 2. Install Ruby dependencies
# -----------------------------------------------------------------------------
echo "📦 Installing Ruby gems..."

if ! command -v bundle &> /dev/null; then
    gem install bundler
fi

bundle check || bundle install

# -----------------------------------------------------------------------------
# 3. Install JavaScript dependencies (if applicable)
# -----------------------------------------------------------------------------
if [ -f "package.json" ]; then
    echo "📦 Installing JavaScript dependencies..."

    if [ -f "yarn.lock" ]; then
        yarn install --frozen-lockfile
    elif [ -f "package-lock.json" ]; then
        npm ci
    else
        npm install
    fi
fi

# -----------------------------------------------------------------------------
# 4. Setup environment variables
# -----------------------------------------------------------------------------
echo "🔐 Setting up environment..."

# Copy credentials template if needed
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    cp .env.example .env
    echo "📝 Created .env from .env.example"
fi

if [ ! -f ".env.development.local" ] && [ -f ".env.development.local.example" ]; then
    cp .env.development.local.example .env.development.local
    echo "📝 Created .env.development.local from example"
fi

# -----------------------------------------------------------------------------
# 5. Database setup
# -----------------------------------------------------------------------------
echo "🗄️ Setting up database..."

# Check database connectivity first
if rails runner "ActiveRecord::Base.connection" 2>/dev/null; then
    echo "✅ Database connection OK"
else
    echo "⚠️ Database not accessible, attempting to create..."
    rails db:create 2>/dev/null || true
fi

# Run migrations
rails db:prepare 2>/dev/null || rails db:migrate

# Seed if needed (optional, uncomment if required)
# rails db:seed

echo "✅ Database ready"

# -----------------------------------------------------------------------------
# 6. Precompile assets (for production-like testing)
# -----------------------------------------------------------------------------
# Uncomment if needed:
# echo "🎨 Precompiling assets..."
# rails assets:precompile

# -----------------------------------------------------------------------------
# 7. Smoke tests - verify environment works
# -----------------------------------------------------------------------------
echo "🧪 Running smoke tests..."

# Test 1: Rails loads
rails runner "puts '✅ Rails loads OK'" 2>/dev/null || {
    echo "❌ Rails failed to load"
    exit 1
}

# Test 2: Database connection
rails runner "ActiveRecord::Base.connection; puts '✅ Database connection OK'" 2>/dev/null || {
    echo "❌ Database connection failed"
    exit 1
}

# Test 3: Check pending migrations
PENDING=$(rails db:migrate:status 2>/dev/null | grep -c "down" || echo "0")
if [ "$PENDING" -gt 0 ]; then
    echo "⚠️ $PENDING pending migrations"
else
    echo "✅ All migrations applied"
fi

# Test 4: Routes load (catches most configuration errors)
rails runner "Rails.application.routes.routes.count.tap { |c| puts \"✅ #{c} routes loaded\" }" 2>/dev/null || {
    echo "⚠️ Routes may have issues"
}

# Test 5: Run quick test suite (optional, non-blocking)
if [ -f "spec/spec_helper.rb" ]; then
    echo "🧪 Running RSpec quick check..."
    bundle exec rspec --dry-run 2>/dev/null && echo "✅ RSpec loads OK" || echo "⚠️ RSpec issues"
elif [ -d "test" ]; then
    echo "🧪 Running Minitest quick check..."
    rails test --dry-run 2>/dev/null && echo "✅ Minitest loads OK" || echo "⚠️ Minitest issues"
fi

# Test 6: Zeitwerk eager loading (catches autoload issues)
rails runner "Rails.application.eager_load!; puts '✅ Eager loading OK'" 2>/dev/null || {
    echo "⚠️ Eager loading issues (check autoload paths)"
}

# -----------------------------------------------------------------------------
# 8. Summary
# -----------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Rails environment ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To start development server:"
echo "  rails server"
echo "  # or with foreman/overmind:"
echo "  bin/dev"
echo ""
echo "To run tests:"
if [ -f "spec/spec_helper.rb" ]; then
    echo "  bundle exec rspec"
else
    echo "  rails test"
fi
echo ""
echo "To open Rails console:"
echo "  rails console"
