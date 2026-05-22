# Tridrishti Workspace

`tridrishti-ws` is the development workspace for Tridrishti components, SDK notes,
and `i2w` nodes. The main code currently lives in `src/i2w`, a C++20 wrapper around
`iceoryx2-cxx` for passive runtime pub/sub, service-style communication, monotonic
time, and wrapper-owned diagnostics.

## Workspace Layout

```text
.
├── README.md                 # Workspace overview
├── sdks/
│   └── SdksCloneDetail.md    # External SDKs tracked for the project
└── src/
    ├── Detail.md             # Notes for organizing i2w nodes
    └── i2w/                  # C++20 iceoryx2 wrapper library and examples
```

Important `i2w` paths:

- `src/i2w/include/i2w/` - public headers
- `src/i2w/src/` - library implementation
- `src/i2w/examples/pubsub/` - standalone pub/sub example project
- `src/i2w/scripts/build.sh` - library build script
- `src/i2w/DESIGN.md` - runtime and API design notes
- `src/i2w/docs/` - additional development documentation

## Prerequisites

Linux development environment with:

- CMake 3.22 or newer
- C++20 compiler
- `git`
- Rust toolchain with `cargo` and `rustc`

The `i2w` build uses a vendored `iceoryx2` checkout under
`src/i2w/third_party/iceoryx2`. The build script can clone and pin this dependency
for you.

## Build `i2w`

From the workspace root:

```bash
cd src/i2w
./scripts/build.sh
```

Useful build overrides:

```bash
BUILD_TYPE=Release ./scripts/build.sh
I2W_BUILD_DIR=/abs/path/to/build ./scripts/build.sh
I2W_ICEORYX2_SOURCE_DIR=/abs/path/to/iceoryx2 ./scripts/build.sh
```

## Run the Pub/Sub Example

Build the standalone example:

```bash
cd src/i2w/examples/pubsub
./scripts/build.sh
```

Run the demo launcher:

```bash
./scripts/run_demo_pubsub.sh
```

Or run the processes in separate terminals:

```bash
./scripts/run_sub.sh
./scripts/run_error_sub.sh
./scripts/run_pub.sh
```

The example builds:

- `i2w_example_pub`
- `i2w_example_sub`
- `i2w_example_error_sub`

## Using `i2w` From Another CMake Target

`i2w` is intended to be consumed from source:

```cmake
add_subdirectory(path/to/i2w)
target_link_libraries(your_target PRIVATE i2w::i2w)
```

See `src/i2w/examples/pubsub` for a complete standalone consumer.

## SDK Notes

SDK clone/reference notes are tracked in `sdks/SdksCloneDetail.md`. Current SDK
references include:

- HBK MicroStrain MIP SDK
- KISS-ICP
- Ouster SDK

## Adding New Nodes

Place new i2w nodes under `src/`. Each node should include its own README or detail
page covering:

- Purpose and responsibilities
- Build and run instructions
- Topics, services, and message types
- Required SDKs or hardware dependencies
- Diagnostics and known error codes

Keep shared runtime functionality inside `src/i2w` and node-specific behavior inside
the node directory.
