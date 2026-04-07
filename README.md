# Lenna Real-Time FPGA Digital Image Processing Pipeline

This repository contains the RTL design and Vivado project files for a high-performance video processing system. The system captures live video from an OV7670 CMOS sensor, processes the stream through parallelized hardware DSP engines, and outputs the result to a VGA display at 640x480 resolution.

---

## 1. System Clock Domains

The design operates across three primary clock domains managed by the `clock_gen` IP core:

* **System Clock (100 MHz):** Used for master control logic and SCCB initialization.
* **VGA Clock (25 MHz):** Drives the VGA timing signals (HSync/VSync) for 640x480 @ 60Hz.
* **Camera XCLK (24 MHz):** Provided to the OV7670 sensor as the master external clock for pixel generation.

---

## 2. Repository Hierarchy

The following structure represents the actual module organization in the Vivado project:

```text
top (top.v)
├── clock_gen : clk_wiz_1 (Generates 25MHz and 24MHz)
├── top_btn_db : debouncer (Master Reset)
├── OV7670_cam : cam_top (cam_top.v)
│   ├── cam_btn_start_db : debouncer (Trigger Init)
│   ├── configure_cam : cam_init (SCCB Controller)
│   │   ├── OV7670_Registers : cam_rom
│   │   ├── OV7670_config : cam_config
│   │   └── SCCB_HERE : sccb_master
│   └── cam_pixels : cam_capture (Byte-to-Pixel reconstruction)
├── process : image_processing_wrapper (image_processing_wrapper.v)
│   ├── process_red / green / blue : imageprocesstop.v (Parallel DSP Slices)
│   │   ├── IC : imagecontroller (Sliding Window Controller)
│   │   │   └── lb0 - lb3 : linebuffer (Synchronous Row Storage)
│   │   ├── conv : conv_top (Kernel Selector)
│   │   │   ├── sobel : conv_sobel (Edge Detection)
│   │   │   └── generic : conv_generic (Multi-mode Filter)
│   │   └── OB : outputbuffer (AXI-Stream FIFO)
├── pixel_memory : mem_bram (mem_bram.v - Dual-Port Frame Buffer)
└── display_interface : vga_top (vga_top.v)
    └── vga_timing_signals : vga_driver (VGA timing generation)
```

---

## 3. Detailed Module Explanation

![Full Processing Architecture](https://github.com/vishking741/Lenna/blob/main/lenna_blk_diag.png)

### Camera Sensor (OV7670)
The physical image sensor that captures raw visual data.
* **Interface:** It receives the master clock (`xclk`) and outputs a pixel clock (`pclk`), horizontal reference (`href`), and vertical sync (`vsync`).
* **Data Flow:** It outputs 12-bit pixel data in RGB444 format, sent as two consecutive 8-bit bytes via the `pix_byte` bus.

### Camera Top (cam_top)
The management layer for the camera hardware, containing two sub-modules:
* **cam_interface:** Operates at **100 MHz** to handle the SCCB (I2C) initialization. It writes register settings to the sensor to configure resolution and color format.
* **cam_capture:** Synchronizes with the **24 MHz** `pclk`. It samples the byte stream, reconstructs the 12-bit pixels, and generates the write addresses (`o_pix_addr`) for the system.

### Image Processing (image_processing)
The "Brain" of the architecture where real-time filtering occurs.
* **Parallel Architecture:** Uses a MIMD (Multiple Instruction, Multiple Data) approach by splitting the RGB stream into three parallel processors (Red, Green, and Blue).
* **Pipeline:** Takes raw data from `cam_capture` and applies hardware-level effects (like Sobel filters or Sharpening) before passing the modified pixels and addresses to memory.

### Dual-Port Memory (mem_bram)
A high-speed Block RAM that acts as a **Clock Domain Crossing (CDC)** buffer.
* **Synchronization:** Decouples the camera's input timing (**24 MHz**) from the VGA's output timing (**25 MHz**).
* **Simultaneous Access:** Port A handles incoming processed data while Port B simultaneously provides data to the display, preventing screen tearing.

### VGA Controller (vga_top)
The display driver that converts memory data into a standard VGA signal.
* **Timing:** Generates `o_VGA_Hsync` and `o_VGA_Vsync` for 640x480 @ 60Hz.
* **Retrieval:** Constantly requests the next pixel address (`o_VGA_pix_addr`) from BRAM and outputs the 4-bit R, G, and B signals to the hardware DAC.

### Clock Generator (Clock Gen)
The system's timing backbone using an FPGA PLL.
* **xclk:** 24 MHz clock provided to the sensor.
* **clk25m:** 25 MHz standard VGA clock for display logic and memory reading.

---

## 4. Hardware Controls: 15-Bit Switch Hierarchy

The system behavior is controlled in real-time via 15 physical switches (`SW[14:0]`).

### Tier 1: Master Output Control (Visibility)
These switches act as a final hardware gate. If a switch is 0, that color channel is grounded (Black).
* **[SW 14]** : Blue Channel Enable
* **[SW 13]** : Green Channel Enable
* **[SW 12]** : Red Channel Enable

### Tier 2: Color Channel Processing (Filter Selection)
Each 4-bit block controls the mathematical operation for that specific color channel.

| Channel | Mode Select (Sobel vs Generic) | Filter Type (If Generic) |
| :--- | :--- | :--- |
| **RED** | SW[3] | SW[2:0] |
| **GREEN** | SW[7] | SW[6:4] |
| **BLUE** | SW[11] | SW[10:8] |

**Generic Filter Mappings (When Mode Select = 0):**
* `000`: Identity (Raw Camera Data)
* `001`: Box Blur
* `010`: -ve Identity
* `011`: Sharpen
* `100`: Edge detection
* `101`: Prewitt
* `110`: Motion Blur
* `111`: Emboss

---

## 5. Common Configuration Examples

* **Standard Live Video:**
    * Set `SW[14:12]` to `111` (All channels ON).
    * Set `SW[11], SW[7], SW[3]` to `0` (Generic Mode).
    * Set all Filter Types to `000` (Identity).

* **Full Sobel Edge Detection:**
    * Set `SW[14:12]` to `111`.
    * Set `SW[11], SW[7], SW[3]` to `1` (All channels in Sobel Mode).

* **Night Vision (Monochrome Green):**
    * Set `SW[14:12]` to `010` (Only Green enabled).
    * Set `SW[7]` to `1` (Sobel) for high-contrast edges.

---

## 6. Build and Constraints
* **Target Clock:** 100 MHz (System), 25 MHz (VGA), 24 MHz (Camera XCLK).
* **Resolution:** 640x480 @ 60Hz.
* **IP Dependencies:** Clock Wizard (`clk_wiz_1`), FIFO Generator (`outputbuffer`), and Dual-Port BRAM.
* **Constraints:** Ensure the `.xdc` file correctly maps the `SIOC`, `SIOD`, `PCLK`, and VGA pins to your specific FPGA development board.
