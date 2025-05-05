FROM haskell:latest
LABEL author="Marco Cetica"

# Set working directory
WORKDIR /opt/zephyr

# Update package list
RUN cabal update

# Build dependencies
COPY zephyr.cabal /opt/zephyr/
RUN cabal build --only-dependencies

# Copy source files
COPY . /opt/zephyr

# Run unit tests
RUN cabal test

# Clean build directory
RUN cabal clean

# Build the rest of the application
RUN cabal install

# Strip binary file
RUN strip /root/.local/bin/zephyr

CMD ["zephyr"]