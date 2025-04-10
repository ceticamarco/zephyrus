FROM haskell:latest
LABEL author="Marco Cetica"

# Set working directory
WORKDIR /opt/zephyrus
COPY . /opt/zephyrus

# Update package list
RUN cabal update

# Build dependencies
COPY ./zephyrus.cabal /opt/zephyrus/zephyrus.cabal
RUN cabal build --only-dependencies

# Run unit tests
RUN cabal test

# Build the rest of the application
RUN cabal install

# Strip binary file
RUN strip /root/.local/bin/zephyrus

CMD ["zephyrus"]