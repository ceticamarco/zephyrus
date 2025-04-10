FROM haskell:latest
LABEL author="Marco Cetica"

# Set working directory
WORKDIR /opt/zephyrus

# Update package list
RUN cabal update

# Build dependencies
COPY zephyrus.cabal /opt/zephyrus/
RUN cabal build --only-dependencies

# Copy source files
COPY . /opt/zephyrus

# Run unit tests
RUN cabal test

# Clean build directory
RUN cabal clean

# Build the rest of the application
RUN cabal install

# Strip binary file
RUN strip /root/.local/bin/zephyrus

CMD ["zephyrus"]