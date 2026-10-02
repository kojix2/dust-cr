# dust-cr

A Crystal reimplementation of the Rust disk usage tool
[dust](https://github.com/bootandy/dust), based on dust v1.2.6

## Build

Requires Crystal 1.21.1 or newer. Linux and macOS are supported; Windows is
not currently supported.

```sh
shards build --release
```

The executable is written to `bin/dust`.

## Usage

```sh
bin/dust             # current directory
bin/dust /var/log    # specified directory
bin/dust --help
```

## License

[Apache License 2.0](LICENSE)
