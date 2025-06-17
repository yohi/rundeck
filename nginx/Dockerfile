# syntax=docker/dockerfile:1
ARG NGINX_VERSION

FROM nginx:${NGINX_VERSION}

WORKDIR /nginx

# Copy nginx configuration files
COPY ./config/nginx.conf /etc/nginx/nginx.conf.template
COPY ./config/default.conf /etc/nginx/templates/default.conf.template

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
