# Build stage for Vue.js frontend
FROM node:14-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage - serve with simple http server
FROM node:14-alpine

WORKDIR /app

# Install serve to host the static files
RUN npm install -g serve

# Copy built files from builder
COPY --from=builder /app/dist ./dist

EXPOSE 80

# Serve the built files
CMD ["serve", "-s", "dist", "-l", "80"]
