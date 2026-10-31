# Temporary STM MOSFET CLI

This standalone package calls the existing STM node's local
`/set_mosfet_service`. It does not open the STM UART.

Build from this directory:

```bash
cmake -S . -B build -DI2W_ECAL_DIR=../i2w/build/third_party/ecal-install
cmake --build build --target mosfet_cli -j4
```

With `stm_node` running on the same host:

```bash
./build/mosfet_cli 2 on
./build/mosfet_cli 2 off
```

IDs 1–7 are accepted. Exit code 0 means the STM node accepted the request;
the service does not wait for or verify the hardware ACK.
