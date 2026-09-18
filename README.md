# Async-fifo-cdc-core
Synthesizable 32x16 Asynchronous FIFO Memory Buffer in Verilog HDL. Features 2-stage FF synchronizers for CDC metastability mitigation and custom verification safety assertions.

# Dual-Clock Asynchronous FIFO Memory Buffer with Runtime Assertions

## 1. Project Overview
This project presents the RTL design and structural verification of a parameterized **Asynchronous FIFO (First-In, First-Out)** memory buffer core using synthesizable Verilog HDL. 

The architecture is explicitly engineered to bridge data pipelines across **Clock Domain Crossing (CDC)** boundaries without data corruption, metastability, or race conditions. It coordinates safe data synchronization between two completely independent clock trees: a **Fast Write Clock (100MHz)** and a **Slower Read Clock (50MHz)**, which is a critical framework used in modern System-on-Chip (SoC) microarchitectures.

---

## 2. Key Architecture & Features
* **Multi-Flop CDC Synchronization:** Integrates a structural **2-Flip-Flop (2-FF) Synchronizer** chain to transition critical pointer control paths between mismatched clock domains, effectively improving Mean Time Between Failures (MTBF).
* **Single-Bit Transition Pointers:** Converts multi-bit binary counter values into **Gray Code format** before crossing clock boundaries, preventing erratic glitch values during clock-edge race events.
* **Functional Safety Assertions:** Implemented concurrent runtime tracking loops to act as hardware assertions, throwing immediate fatal system flags on the terminal during unexpected boundary crashes.
* **Fully Parameterized Framework:** Engineered with modular constraints allowing immediate hardware scaling by updating top-level `DATA_WIDTH` (currently 16-bit) and `ADDR_WIDTH` (currently 5-bit for a 32-row deep matrix).

---

## 3. Hardware Component Block Diagram

```text
                  +--------------------------------------------------------+

                  |              my_custom_async_fifo (DUT)                |
                  |                                                        |
 clk_write ------>|  +--------------------+        +--------------------+  |
 rst_write_n ---->|  |                    |        |                    |  |
 write_increment->|  | write_domain_ctrl  |------->| fifo_storage_core  |  |
 data_in_bus ---->|  |                    | waddr  | [32x16 Register]   |  |

                  |  +--------------------+        |                    |  |
                  |         |                      +--------------------+  |
                  |         | wptr (Gray)                    |             |
                  |         v                                v             |
                  |  +--------------------+                  |             |
                  |  |cdc_bits_synchronizer|                 |             |
                  |  | [2-Stage FF Chain] |                  |             |
                  |  +--------------------+                  |             |
                  |         |                                |             |
                  |         +---------------------------+    |             |
                  |                                     |    |             |
                  |                                     v    v             |
 clk_read ------->|  +--------------------+        +--------------------+  |
 rst_read_n ----->|  |                    |        |                    |  |
 read_increment ->|  |  read_domain_ctrl  |<-------|    Data Read Bus   |--+----> data_out_bus [15:0]

                  |  |                    | raddr  +--------------------+  |
                  |  +--------------------+                                |
                  |         |                                              |
                  |         | rptr (Gray)                                  |
                  |         v                                              |
                  |  +--------------------+                                |
                  |  |cdc_bits_synchronizer|                               |
                  |  +--------------------+                                |
                  |         |                                              |
                  |         +----------------------------------------------+
 buffer_full <----+-- [Saturate Boundary Flag]                             |
 buffer_empty <---+-- [Drained Baseline Flag]                              |
                  +--------------------------------------------------------+
```

---

## 4. Input / Output Signal Table

| Signal Name | Direction | Width | Description / Function |
| :--- | :--- | :--- | :--- |
| `clk_write` | Input | 1 bit | Master Write Clock Line (Fast Domain - 100MHz) |
| `rst_write_n` | Input | 1 bit | Asynchronous Active-Low Reset for Write Logic |
| `write_increment` | Input | 1 bit | Write Strobe / Push operation enable control |
| `data_in_bus[15:0]` | Input | 16 bits | 16-bit incoming parallel payload packet data |
| `clk_read` | Input | 1 bit | Master Read Clock Line (Slow Domain - 50MHz) |
| `rst_read_n` | Input | 1 bit | Asynchronous Active-Low Reset for Read Logic |
| `read_increment` | Input | 1 bit | Read Strobe / Pop operation enable control |
| `data_out_bus[15:0]`| Output | 16 bits | 16-bit stable registered read data output bus |
| `buffer_full` | Output | 1 bit | High flag indicating memory saturation (blocks further writes) |
| `buffer_empty` | Output | 1 bit | High flag indicating memory depletion (blocks further reads) |

---

## 5. Verification Scenarios & Bug Hunting
The design compiled and simulated using the structural **Icarus Verilog 12.0** compiler engine on EDA Playground. Self-checking test patterns were evaluated against a local mirror tracking array to check cycle-accurate bus state validity.

### Key Verified Testcases (Functional Safety Testing):
* **Burst Load Satiation Check:** Forced continuous back-to-back fast write packets up to 34 loop cycles. Verified that upon reaching the exact 32nd pointer register matrix offset, `buffer_full` snapped high instantly, and the internal hardware runtime assertion caught the overflow breach attempt at the next clock tick.
* **Burst Drain Starvation Check:** Executed continuous slow reads on the populated slots. Verified that `buffer_full` dropped instantly on the first loop read and tracked data down until `buffer_empty` pulled high, blocking data corruption gracefully.

---

## 6. Simulation Waveforms
### Asynchronous FIFO Core Simulation Waveform (`waveform.png`)
*(Include your generated EPWave trace plot image here to present the fast write pulses, slow read cycles, and timing flag triggers clearly for design audits).*

