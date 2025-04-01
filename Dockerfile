FROM haskell:latest
LABEL author="Marco Cetica"

# Set working directory
WORKDIR /opt/zephyrus

# Update package list
RUN cabal update

# Build dependencies
COPY ./zephyrus.cabal /opt/zephyrus/zephyrus.cabal
RUN cabal build --only-dependencies

# Build the rest of the application
COPY . /opt/zephyrus
RUN cabal install

# Strip binary file
RUN strip /root/.local/bin/zephyrus

CMD ["zephyrus"]