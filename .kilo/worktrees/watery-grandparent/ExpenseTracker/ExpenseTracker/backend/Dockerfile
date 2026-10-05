FROM node:20-alpine

# Install sharp dependencies
RUN apk add --no-cache vips-dev fftw-dev gcc g++ make python3

WORKDIR /app

# Install dependencies first (layer cache)
COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# Create upload + log dirs
RUN mkdir -p uploads logs

EXPOSE 3000

CMD ["node", "src/index.js"]
