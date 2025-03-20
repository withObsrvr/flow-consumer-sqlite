# Obsrvr Flow SQLite Consumer

A plugin for Obsrvr Flow that stores data in a SQLite database.

## Features

- Auto-creates tables based on data structure
- Dynamically adjusts column types
- Handles different data formats
- Stores metadata about database operations

## Building with Nix

This project uses Nix for reproducible builds.

### Prerequisites

- [Nix package manager](https://nixos.org/download.html) with flakes enabled

### Building

1. Clone the repository:
   ```
   git clone https://github.com/withObsrvr/flow-consumer-sqlite.git
   cd flow-consumer-sqlite
   ```

2. Build with Nix:
   ```
   nix build
   ```

The built plugin will be available at `./result/lib/flow-consumer-sqlite.so`.

### Development

To enter a development shell with all dependencies:

```
nix develop
```

## Configuration

When using the plugin, you can configure the path to the SQLite database file:

```json
{
  "db_path": "path/to/your/database.db"
}
```

## License

[License information]