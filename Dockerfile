FROM golang:alpine
LABEL author="Marco Cetica"

# Prepare working directory
RUN mkdir /app
WORKDIR /app

# Copy source files
COPY . .

# Build the application
RUN go build -ldflags="-s -w" -o zephyr

# Run the app
EXPOSE 3000

CMD ["./zephyr"]