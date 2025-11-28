# Node.js todos service
FROM node:14-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

EXPOSE 8082

CMD ["node", "server.js"]
