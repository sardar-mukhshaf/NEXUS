# =============================================================================
# NEXUS PLATFORM — Backstage Dockerfile
# Multi-stage build, non-root user, distroless final image.
# =============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build
# ------------------------------------------------------------------------------
FROM node:18-bookworm-slim AS build

WORKDIR /app

# Install dependencies for native modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn
COPY packages ./packages

# Install dependencies
RUN yarn install --immutable

# Copy source code
COPY . .

# Build Backstage
RUN yarn tsc
RUN yarn build:backend

# ------------------------------------------------------------------------------
# Stage 2: Production
# ------------------------------------------------------------------------------
FROM node:18-bookworm-slim

WORKDIR /app

# Install production dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r backstage && useradd -r -g backstage backstage

# Copy built application from build stage
COPY --from=build --chown=backstage:backstage /app/packages/backend/dist ./packages/backend/dist
COPY --from=build --chown=backstage:backstage /app/packages/backend/package.json ./packages/backend/
COPY --from=build --chown=backstage:backstage /app/yarn.lock ./
COPY --from=build --chown=backstage:backstage /app/package.json ./
COPY --from=build --chown=backstage:backstage /app/.yarn ./.yarn
COPY --from=build --chown=backstage:backstage /app/.yarnrc.yml ./

# Install production dependencies
RUN yarn workspaces focus --all --production && rm -rf $(yarn cache clean)

# Switch to non-root user
USER backstage

# Expose port
EXPOSE 7007

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:7007/healthcheck', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start Backstage
CMD ["node", "packages/backend/dist/index.cjs.js"]
