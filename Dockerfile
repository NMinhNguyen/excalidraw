FROM node:14-alpine AS deps

ARG REACT_APP_INCLUDE_GTAG=false

RUN mkdir /opt/node_app && chown node:node /opt/node_app
WORKDIR /opt/node_app

USER node

COPY package.json package-lock.json ./
RUN npm install --no-optional && npm cache clean --force
ENV PATH /opt/node_app/node_modules/.bin:$PATH

WORKDIR /opt/node_app
COPY . .

FROM node:14-alpine AS build

ARG NODE_ENV=production

WORKDIR /opt/node_app
COPY --from=deps /opt/node_app .
RUN npm run build:app:docker

FROM rust:alpine AS rust-build

WORKDIR /set-runtime-config
COPY scripts/set-runtime-config .
RUN cargo build --release

FROM nginx:1.19-alpine

COPY --from=build /opt/node_app/build /usr/share/nginx/html
COPY --from=rust-build /set-runtime-config/target/release/set-runtime-config ./
COPY --from=rust-build /set-runtime-config/set-runtime-config.sh /docker-entrypoint.d

HEALTHCHECK CMD wget -q -O /dev/null http://localhost || exit 1
