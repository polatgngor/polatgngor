# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /usr/src/app

# Install dependencies first (cachlayering)
COPY package*.json ./
# Install ALL dependencies (including dev) to build/test if needed, 
# or just --production if no build step. 
# Since we have no build step for backend (it's JS), we can just install.
RUN npm ci

# Copy source
COPY . .

# Stage 2: Production
FROM node:18-alpine

WORKDIR /usr/src/app

# Install only production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source from builder (or local if no build step needed, but good practice)
COPY --from=builder /usr/src/app/src ./src
COPY --from=builder /usr/src/app/server.js ./
# Copy other necessary files
# Copy startup/scripts if needed
COPY --from=builder /usr/src/app/src/startup ./src/startup

# Create uploads directory
RUN mkdir -p uploads && chown -R node:node uploads

# Switch to non-root user
USER node

EXPOSE 3000

CMD ["node", "server.js"]
