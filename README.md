# FPGA Audio Processing Chain — I2S → Upsampling → FIR → Phase → IQ → I2S

Dit project implementeert een complete digitale audioketen op een Xilinx Spartan‑6 FPGA.  
De keten ontvangt een I2S‑audiosignaal van een externe DSP, verwerkt het intern op hogere samplefrequenties, genereert IQ‑signalen via een fase‑accumulator en LUT, en stuurt deze als I2S‑stereo uit naar een PCM5102 DAC.

Het ontwerp bevat een robuuste klok‑failover, noodklokken, automatische omschakeling, en een Arduino‑SPI interface voor live parameter‑aanpassing.

---

## 🚀 Functionaliteitsoverzicht

- **I2S‑ingang (RX)**  
  - 12.288 MHz BCLK  
  - 192 kHz LRCLK  
  - 32‑bit samples  
  - Automatische failover naar noodklokken bij DSP‑klokverlies

- **Upsampler (192 kHz → 384 kHz)**  
  - Verdubbelt de samplefrequentie  
  - Levert stabiele strobe‑signalen voor verdere verwerking

- **FIR‑filter**  
  - 63‑tap low‑pass filter  
  - Schakelbaar via `bypass`

- **Phase Accumulator**  
  - 16‑bit fasewoord  
  - Test‑signaal injectie  
  - Perfecte synchronisatie met de audiostroom

- **IQ‑generator (LUT90)**  
  - 90‑degree quadrature sinus LUT  
  - 16‑bit I/Q output  
  - Uitbreiding naar 32‑bit voor FIR‑IQ filters

- **FIR‑IQ filters**  
  - Gescheiden filtering voor I en Q  
  - Perfecte frame‑uitlijning via “wachtkamer‑oplossing”

- **I2S‑uitgang (TX)**  
  - 24.576 MHz BCLK via ODDR2  
  - 384 kHz LRCLK  
  - Stereo I/Q naar PCM5102 DAC  
  - Arduino‑SPI interface voor live fase‑adjustment

- **Watchdog & Noodklokken**  
  - Detecteert verlies van DSP‑BCLK  
  - Schakelt automatisch naar interne 12.288 MHz & 192 kHz noodklokken  
  - Reset‑manager voor stabiele opstart

---

## 🧩 Module‑overzicht

### 1. `Reset`
Power‑on reset, noodklokgeneratie en stabilisatie van alle modules.

### 2. `watchdog`
Detecteert of de DSP‑BCLK wegvalt.  
Stuurt LED‑status en failover‑signaal.

### 3. `emg_clock12288` & `Emergency_clocks`
Interne noodklokken:
- 12.288 MHz
- 192 kHz

### 4. Multiplexer
Schakelt automatisch tussen DSP‑klokken en noodklokken.

### 5. `clock_doublerA`
PLL die 24.576 MHz en 49.152 MHz genereert.

### 6. `I2SRX`
Ontvangt I2S‑samples en levert 32‑bit audio + strobe.

### 7. `Upsampler`
Verdubbelt samplefrequentie naar 384 kHz.

### 8. `FIR_Filter`
63‑tap FIR voor filtering na upsampling.

### 9. `PHASEACCUMULATOR`
Genereert fase‑woorden op basis van audio‑amplitude.

### 10. `LUT90`
Maakt I/Q‑sinussen op basis van fase.

### 11. `FIR_IQ`
Filtert I en Q afzonderlijk.

### 12. `I2STX`
Stuurt I/Q als stereo I2S naar PCM5102 DAC.  
Bevat Arduino‑SPI interface voor:
- `phase_adj`
- test‑signaal
- debug‑pins

---



---

## 🔧 Hardware

- **FPGA:** Xilinx Spartan‑6  
- **DAC:** PCM5102  
- **DSP:** Externe I2S‑bron (master)  
- **Arduino:** SPI interface voor live control  
- **Clocking:** 12.288 MHz / 24.576 MHz / 49.152 MHz

---

## 🛠 Build & Synthese

Project is bedoeld voor:

- Xilinx ISE 14.7  
- Spartan‑6 LX9 / LX16  
- Verilog HDL

Synthese‑instellingen:
- Optimize for speed  
- Keep hierarchy  
- Register balancing enabled  

---

## 🧪 Testsignalen

- `test_signal` kan via Arduino worden geactiveerd  
- Debug‑pins beschikbaar voor scope‑meting:
  - `debug_pin3`
  - `debug_pin4`
  - `debug_pin5`
  - `debug_pin6`

---

## 👤 Auteur

**Willem**  
Embedded DSP, FPGA‑design, I2S‑audio, IQ‑modulatie, en hardware‑debugging.

---

## 📄 Licentie

MIT‑licentie of eigen licentie naar keuze.



## 📁 Bestandsstructuur


┌──────────────────────────────────────────────────────────────────────────────┐
│                                TopView (FPGA)                                │
└──────────────────────────────────────────────────────────────────────────────┘

        ┌──────────────┐
        │   DSP I2S     │
        │  (Master)     │
        └──────┬────────┘
               │  i2s_in_bclk / lrclk / data
               ▼
        ┌──────────────────┐
        │     Watchdog      │◄───────────────┐
        │  (BCLK monitor)   │                │
        └──────┬───────────┘                │
               │ bclk_is_missing            │
               ▼                            │
        ┌──────────────────┐                │
        │  LockSolution     │                │
        │  (clean_dsp_weg)  │                │
        └──────┬───────────┘                │
               │                            │
               ▼                            │
        ┌──────────────────────────────────────────────┐
        │                Clock MUX                      │
        │  active_bclk  = DSP or Emergency 12.288 MHz  │
        │  active_lrclk = DSP or Emergency 192 kHz     │
        └────────┬─────────────────────────────────────┘
                 │
                 ▼
        ┌──────────────────┐
        │   PLL / DCM       │
        │ 24.576 MHz / 49.152 MHz
        └────────┬─────────┘
                 │ clk_24576 / clk_49152
                 ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                              AUDIO PROCESSING                                │
└──────────────────────────────────────────────────────────────────────────────┘

        ┌──────────────────┐
        │     I2SRX         │
        │  32-bit samples   │
        └──────┬───────────┘
               │ rx_sample, strobe_w1
               ▼
        ┌──────────────────┐
        │    Upsampler      │
        │ 192 kHz → 384 kHz │
        └──────┬───────────┘
               │ up_sample, strobe_384
               ▼
        ┌──────────────────┐
        │    FIR Filter     │
        │   63-tap LPF      │
        └──────┬───────────┘
               │ filtered_sample, strobe_filtered
               ▼
        ┌──────────────────┐
        │ Phase Accumulator │
        │   phase_w (16-bit)│
        └──────┬───────────┘
               │ strobe_w2
               ▼
        ┌──────────────────┐
        │     LUT90         │
        │   I/Q generator   │
        └──────┬───────────┘
               │ I16, Q16, iq_valid
               ▼
        ┌──────────────────┐
        │   FIR_IQ Filters  │
        │  I_filtered/Q_filtered
        └──────┬───────────┘
               │ safe_tx_strobe
               ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                                I2S OUTPUT                                    │
└──────────────────────────────────────────────────────────────────────────────┘

        ┌──────────────────┐
        │     I2STX         │
        │  Stereo I/Q → DAC │
        │  SPI control      │
        └──────┬───────────┘
               │ i2s_out_data / lrclk
               ▼
        ┌──────────────────┐
        │     ODDR2F        │
        │ 24.576 MHz BCLK   │
        └──────┬───────────┘
               ▼
        PCM5102 DAC


