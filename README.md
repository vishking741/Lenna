# LENNA 
# Real-Time FPGA Digital Image Processor (OV7670 to VGA) 

This repository contains the complete RTL design and IP configurations for a high-performance, real-time image processing pipeline. The system interfaces with an OV7670 CMOS camera, processes live video data through parallelized DSP hardware engines, and outputs the resulting frames to a VGA display at 640x480 resolution.

---

## 1. System Architecture and Data Flow

The design is architected as a high-throughput streaming pipeline, handling multiple clock domains to ensure stability and real-time performance.

### Data Path Overview
1.  **Input (Camera):** Raw byte streams are captured from the OV7670 sensor at a 24 MHz Pixel Clock (PCLK).
2.  **Processing (The Wrapper):** Data is intercepted by the `image_processing_wrapper` before reaching memory. This allows for "zero-latency" visual effects.
3.  **Buffering (BRAM):** Processed pixels are stored in a Dual-Port Block RAM. This serves as a Clock Domain Crossing (CDC) bridge between the Camera clock (24 MHz) and the VGA clock (25 MHz).
4.  **Output (VGA):** The VGA controller reads from the BRAM and generates the required HSync and VSync timing signals for display.



---

## 2. Repository Structure and Hierarchy

The following hierarchy represents the organization of the hardware modules within the Vivado project:

* **top (top.v)** - The main system orchestrator.
    * **clock_gen** (clk_wiz_1.xci) - Generates 25 MHz (VGA) and 24 MHz (Camera XCLK).
    * **top_btn_db** (debounce.v) - Master reset debouncer.
    * **OV7670_cam** (cam_top.v) - The Camera Subsystem.
        * **cam_btn_start_db** - Trigger for camera initialization.
        * **configure_cam** (cam_init.v) - SCCB/I2C Controller.
            * **OV7670_Registers** (cam_rom.v) - Configuration register set.
            * **OV7670_config** (cam_config.v) - SCCB state machine.
            * **SCCB_HERE** (sccb_master.v) - I2C physical layer.
        * **cam_pixels** (cam_capture.v) - Byte-to-pixel reconstruction.
    * **process** (image_processing_wrapper.v) - **The Processing Core.**
        * **process_red/green/blue** (imageprocesstop.v) - Three parallel DSP slices.
            * **IC** (imagecontroller.v) - Line buffering for spatial convolution.
                * **lb0 - lb3** (linebuffer.v) - Synchronous shift registers for row storage.
            * **conv** (conv_top.v) - Mathematical kernel selector.
                * **sobel** (conv_sobel.v) - Edge detection logic.
                * **generic** (conv_generic.v) - Blur/Sharpen/Emboss logic.
            * **OB** (outputbuffer.xci) - AXI-Stream FIFO for flow control.
    * **pixel_memory** (mem_bram.v) - Dual-port 12-bit Frame Buffer.
    * **display_interface** (vga_top.v) - VGA output controller.
        * **vga_timing_signals** (vga_driver.v) - Standard 640x480 @ 60Hz timing.

---

## 3. Detailed Module Explanation

### Camera Module (cam_top)
The camera module is responsible for bringing the OV7670 hardware into a functional state. 
* **Initialization:** Upon a 'Start' signal, the `cam_init` block uses the SCCB protocol (I2C) to write specific register values to the camera. This configures the sensor for RGB444 output, sets the gain, and optimizes exposure.
* **Capture:** The `cam_capture` module watches the `PCLK`, `HREF`, and `VSYNC` signals. Because the camera sends 12-bit pixels as two 8-bit bytes, this module performs the concatenation and generates a `write_enable` signal only when a full pixel is ready.

### Image Processing Wrapper (image_processing_wrapper)
This module is the "Brain" of the visual effects. To maintain a real-time 60 FPS stream, it uses a MIMD (Multiple Instruction, Multiple Data) approach:
* **Parallelism:** It splits the RGB pixel into three separate streams. This allows the FPGA to process the Red, Green, and Blue components in parallel using dedicated hardware logic.
* **Line Buffering:** To perform a convolution (like Sobel), the hardware needs to look at a 3x3 grid of pixels. The `imagecontroller` uses `linebuffers` to store previous lines of video, effectively creating a sliding window that moves across the image as it streams from the camera.
* **Recombination:** After the DSP slices finish their calculations, the wrapper recombines the results and applies a Master Mask (switches 14:12) before sending the data to the BRAM.



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
* `001`: Gaussian Blur
* `010`: Sharpen
* `011`: Mean Blur
* `100`: Emboss

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
* **Target Clock:** 100 MHz (System), 25.175 MHz (VGA), 24 MHz (Camera XCLK).
* **Resolution:** 640x480 @ 60Hz.
* **IP Dependencies:** Clock Wizard (`clk_wiz_1`), FIFO Generator (`outputbuffer`), and Dual-Port BRAM.
* **Constraints:** Ensure the `.xdc` file correctly maps the `SIOC`, `SIOD`, `PCLK`, and VGA pins to your specific FPGA development board.
