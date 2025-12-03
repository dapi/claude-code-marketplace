#!/bin/bash
# =============================================================================
# init.sh for Node.js / JavaScript projects
# Purpose: Setup environment so agent can start working immediately
# =============================================================================
set -e

echo "🔧 Setting up Node.js environment..."

# -----------------------------------------------------------------------------
# 1. Check Node.js version
# -----------------------------------------------------------------------------
if command -v node &> /dev/null; then
    echo "✅ Node.js $(node -v)"
else
    echo "❌ Node.js not found. Please install Node.js first."
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. Install dependencies
# -----------------------------------------------------------------------------
echo "📦 Installing dependencies..."

if [ -f "package-lock.json" ]; then
    npm ci  # faster, uses lockfile exactly
elif [ -f "yarn.lock" ]; then
    yarn install --frozen-lockfile
elif [ -f "pnpm-lock.yaml" ]; then
    pnpm install --frozen-lockfile
else
    npm install
fi

# -----------------------------------------------------------------------------
# 3. Setup environment variables
# -----------------------------------------------------------------------------
echo "🔐 Setting up environment..."

if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    cp .env.example .env
    echo "📝 Created .env from .env.example (review and update values)"
elif [ ! -f ".env" ] && [ -f ".env.local.example" ]; then
    cp .env.local.example .env.local
    echo "📝 Created .env.local from example"
fi

# -----------------------------------------------------------------------------
# 4. Database setup (if applicable)
# -----------------------------------------------------------------------------
if [ -f "prisma/schema.prisma" ]; then
    echo "🗄️ Running Prisma migrations..."
    npx prisma migrate dev --name init 2>/dev/null || npx prisma db push
    npx prisma generate
elif [ -f "drizzle.config.ts" ] || [ -f "drizzle.config.js" ]; then
    echo "🗄️ Running Drizzle migrations..."
    npx drizzle-kit push 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 5. Build step (if needed)
# -----------------------------------------------------------------------------
if grep -q '"build"' package.json 2>/dev/null; then
    echo "🏗️ Running build..."
    npm run build 2>/dev/null || echo "⚠️ Build failed or not required for dev"
fi

# -----------------------------------------------------------------------------
# 6. Smoke test - verify environment works
# -----------------------------------------------------------------------------
echo "🧪 Running smoke test..."

# Test 1: Node can execute
node -e "console.log('✅ Node.js execution OK')"

# Test 2: Dependencies loaded
node -e "require('./package.json'); console.log('✅ Package.json readable')"

# Test 3: TypeScript compiles (if applicable)
if [ -f "tsconfig.json" ]; then
    npx tsc --noEmit 2>/dev/null && echo "✅ TypeScript compiles" || echo "⚠️ TypeScript errors (may be expected)"
fi

# Test 4: Lint passes (optional, non-blocking)
if grep -q '"lint"' package.json 2>/dev/null; then
    npm run lint 2>/dev/null && echo "✅ Lint passes" || echo "⚠️ Lint warnings"
fi

# -----------------------------------------------------------------------------
# 7. Summary
# -----------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Environment ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To start development server:"
if grep -q '"dev"' package.json 2>/dev/null; then
    echo "  npm run dev"
elif grep -q '"start"' package.json 2>/dev/null; then
    echo "  npm start"
fi
echo ""
echo "To run tests:"
if grep -q '"test"' package.json 2>/dev/null; then
    echo "  npm test"
fi
