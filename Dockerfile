FROM node:18-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src/ src/
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist/ dist/
ENV MCP_TRANSPORT=http
ENV MCP_PORT=8080
EXPOSE 8080
ENTRYPOINT ["node", "dist/index.js"]
