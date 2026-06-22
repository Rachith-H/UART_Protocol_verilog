# Full-Duplex UART Peripheral — Verilog RTL

A synthesizable, full-duplex UART peripheral written in Verilog. Supports optional even parity, configurable baud rate, and a simple register-mapped bus interface. Verified via a self-checking full-duplex testbench with two independent UART instances communicating at ~9600 baud across different clock domains.

---

## Features

- Full-duplex TX and RX operation
- Optional even parity (configurable per transfer)
- Framing error and overrun detection on RX
- Center-sampling RX — half-baud tick aligns sample to bit center for noise immunity
- Separate baud generators for TX and RX, each independently gated
- Register-mapped control interface (`CTRL`, `STATUS`, `TXDATA`, `RXDATA`, `BAUD_CNT`)
- FSM-based TX and RX datapaths (3-state: IDLE → TRANSFER/RECEIVE → DONE)
- Verified with two UART instances at 100 MHz and 50 MHz clocks, both running ~9600 baud

---

## Block Diagram

```
                   ┌──────────────────────────────────────┐
                   │             UART_top                  │
                   │                                       │
  Bus Interface ──►│  ctrl / baud_cnt / tx_data registers  │
  (sel, en,        │  status / rx_data read mux            │
   offset, d_in,   │                                       │
   d_out, ready)   │  ┌──────────┐      ┌──────────────┐  │
                   │  │ tx_UART  │      │   rx_UART    │  │
                   │  │  TX FSM  │      │   RX FSM     │  │
                   │  │          │      │ (hf_baud     │  │
                   │  └────┬─────┘      │  center-samp)│  │
                   │       │            └──────┬───────┘  │
                   │  ┌────▼─────┐    ┌────────▼──────┐   │
                   │  │ baud_gen │    │   baud_gen    │   │
                   │  │ (TX clk) │    │   (RX clk)    │   │
                   │  └──────────┘    └───────────────┘   │
                   └──────────────────────────────────────┘
                          │                    ▲
                         TX                   RX
```

---

## Module Reference

### `UART_top.v`

Top-level integration module. Instantiates TX, RX, and two independent baud generators. Exposes a word-addressed register interface.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | I | 1 | System clock |
| `rst` | I | 1 | Active-high synchronous reset |
| `sel` | I | 1 | Peripheral select |
| `en` | I | 1 | Write enable (1=write, 0=read) |
| `offset` | I | 3 | Register address (see register map) |
| `d_in` | I | 32 | Write data |
| `d_out` | O | 32 | Read data |
| `ready` | O | 1 | Write acknowledge (1 cycle pulse) |
| `TX` | O | 1 | Serial transmit line |
| `RX` | I | 1 | Serial receive line |

---

### `tx_UART.v`

FSM-based transmitter. Serializes 8 data bits LSB-first with a start bit (logic 0) and optional even parity before the stop bit (logic 1).

**States:** `IDLE → TRANSFER → DONE`

| Port | Dir | Description |
|------|-----|-------------|
| `clk`, `rst` | I | Clock, active-high reset |
| `tx_en` | I | TX enable (from `ctrl[0]`) |
| `par_en` | I | Parity enable (from `ctrl[2]`) |
| `baud_tic` | I | Baud tick from baud generator |
| `tx_data[7:0]` | I | Byte to transmit |
| `tx_st` | I | Transmit strobe (write to TXDATA register) |
| `TX` | O | Serial output line |
| `tx_busy` | O | High while frame in progress |
| `baud_en` | O | Gates the TX baud generator |

---

### `rx_UART.v`

FSM-based receiver with center-sampling. Start bit is detected on a falling edge of `RX`; the receiver waits for `hf_baud` (half-baud tick) to re-sample at the bit center before transitioning to RECEIVE, rejecting glitches shorter than half a baud period.

**States:** `IDLE → RECEIVE → DONE`

| Port | Dir | Description |
|------|-----|-------------|
| `clk`, `rst` | I | Clock, active-high reset |
| `rx_en` | I | RX enable (from `ctrl[1]`) |
| `par_en` | I | Parity enable (from `ctrl[2]`) |
| `baud_tic` | I | Full baud tick |
| `hf_baud` | I | Half-baud tick (center-sample reference) |
| `RX` | I | Serial input line |
| `rx_read` | I | Read strobe — clears `rx_val` and `overrun` |
| `rx_data[7:0]` | O | Received byte |
| `rx_val` | O | High when a valid byte is ready |
| `par_error` | O | Even parity mismatch detected |
| `fr_error` | O | Framing error (stop bit not logic 1) |
| `overrun` | O | New frame started before previous byte was read |
| `baud_en` | O | Gates the RX baud generator |

---

### `baud_gen.v`

Parameterized clock divider. Counts up to `baud_cnt` and generates a 1-cycle `baud_tic` pulse, plus a `hf_baud` pulse at the halfway point for center-sampling. Gated by `en` — counter resets when disabled.

| Port | Dir | Description |
|------|-----|-------------|
| `clk`, `rst` | I | Clock, active-high reset |
| `en` | I | Enable (gated by TX/RX FSM) |
| `baud_cnt[15:0]` | I | Divider value = `CLK_FREQ / BAUD_RATE` |
| `baud_tic` | O | Full baud tick (`count == baud_cnt`) |
| `hf_baud` | O | Half-baud tick (`count == baud_cnt >> 1`) |

**Baud divisor formula:**
```
baud_cnt = CLK_FREQ / BAUD_RATE
```

---

## Register Map

Accessed via `offset[2:0]`. Write: `sel=1, en=1`. Read: `sel=1, en=0`.

| Offset | Name | Access | Width | Description |
|--------|------|--------|-------|-------------|
| `3'd0` | `CTRL` | R/W | 8-bit | `[0]` TX enable, `[1]` RX enable, `[2]` Parity enable |
| `3'd1` | `STATUS` | R | 8-bit | `[0]` TX busy, `[1]` RX valid, `[2]` Framing error, `[3]` Parity error, `[4]` Overrun |
| `3'd2` | `TXDATA` | W | 8-bit | Write byte to transmit; write strobe triggers TX |
| `3'd3` | `RXDATA` | R | 8-bit | Read received byte; clears `rx_val` and `overrun` |
| `3'd4` | `BAUD_CNT` | R/W | 16-bit | Baud divisor (`CLK_FREQ / BAUD_RATE`) |

---

## Directory Structure

```
.
├── rtl/
│   ├── UART_top.v          # Top-level with register interface
│   ├── tx_UART.v           # TX FSM
│   ├── rx_UART.v           # RX FSM with center-sampling
│   └── baud_gen.v          # Parameterized baud generator
├── tb/
│   └── uart_fullduplex_tb.v  # Full-duplex testbench (two UART instances)
├── sim/
│   └── waveforms/          # GTKWave screenshots
├── docs/
│   └── rtl_schematic/      # RTL schematic screenshots
└── README.md
```

---

## Simulation — Full-Duplex Testbench

The testbench instantiates two `UART_top` instances (`uart_A` and `uart_B`) with their TX/RX lines cross-connected, running on independent clocks at different frequencies — both configured to the same baud rate.

| | UART_A | UART_B |
|-|--------|--------|
| Clock | 100 MHz | 50 MHz |
| `BAUD_CNT` | 10416 | 5208 |
| Effective baud | ~9600 | ~9600 |
| `CTRL` | `0x07` (TX+RX+Parity) | `0x07` (TX+RX+Parity) |

**Transfer sequence:**

| Step | UART_A sends | UART_B sends |
|------|-------------|-------------|
| Round 1 | `0xAA` (170) | `0x55` (85) |
| Round 2 | `0x64` (100) | `0x7F` (127) |

Each instance waits on `rx_val` before reading RXDATA and transmitting the next byte — demonstrating synchronized full-duplex handshaking across different clock domains.

### Running the simulation

```bash
# Compile
iverilog -o uart_sim tb/uart_fullduplex_tb.v rtl/UART_top.v rtl/tx_UART.v rtl/rx_UART.v rtl/baud_gen.v

# Run
vvp uart_sim

# View waveforms (if $dumpfile is added to tb)
gtkwave dump.vcd
```

---

## Simulation Waveforms

> *Add waveform screenshots here showing TX/RX lines, rx_val assertion, and rx_data capture.*

<!-- Example: ![Full-duplex waveform](sim/waveforms/fullduplex_wave.png) -->

---

## RTL Schematic

> *Add RTL schematic screenshots here.*

<!-- Example: ![RTL Schematic](docs/rtl_schematic/uart_top_schematic.png) -->

---

## Tools Used

| Tool | Purpose |
|------|---------|
| Icarus Verilog | RTL simulation |
| GTKWave | Waveform analysis |
| Vivado / Yosys | RTL schematic / synthesis |

---

## Author

**Rachith H**  
B.E. ECE — Bapuji Institute of Engineering and Technology, Davangere  
[GitHub](https://github.com/Rachith-H) · [LinkedIn](https://www.linkedin.com/in/) <!-- add your LinkedIn slug -->
