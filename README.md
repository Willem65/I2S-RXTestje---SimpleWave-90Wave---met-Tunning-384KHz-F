# GNU Radio NICAM Decoder & Encoder – Open SDR ZYNQ 7020 / Adalm Pluto

Dit project bevat een volledige set GNU Radio‑flowgraphs en ondersteunende bestanden voor het decoderen en encoderen van NICAM 728 audio via Software Defined Radio.  
De implementatie is getest met:

- Analog Devices Adalm Pluto (Chinees PCB‑versie)
- ZYNQ 7020 Open SDR platform
- GNU Radio 3.x

Het project bevat zowel NICAM RX, NICAM TX als een BPSK‑TX‑RX referentie‑implementatie.

## Projecten Overzicht

In deze repository vind je drie hoofdprojecten:

### 1. NICAM_RX_Final_Fixed
Een complete NICAM 728 decoder‑flowgraph.
Functies:
- Demodulatie van NICAM‑signaal
- FEC‑correctie
- Audio reconstructie
- Debug‑visualisaties (spectrum, constellatie, timing)

### 2. NICAM_TX_Final_Fixed
Een NICAM 728 encoder‑flowgraph.
Functies:
- Audio → NICAM 728 encoding
- BPSK modulatie
- PlutoSDR / ZYNQ output
- Instelbare sample‑rates en symbol‑rates

### 3. Final-BPSK-TX-RX
Referentie‑implementatie voor BPSK‑transmissie en ontvangst.
Functies:
- Basis BPSK‑modulator
- Basis BPSK‑demodulator
- Timing recovery
- Debug‑plots

Alle projecten zijn aanwezig als uitgepakte map én als zip‑bestand.

## Benodigde Software & Hardware

### Software
- GNU Radio (3.x)
- gr-iio (voor PlutoSDR)
- Python 3.x
- libiio / iio-oscilloscope (optioneel)

### Hardware
- Adalm Pluto SDR
- ZYNQ 7020 SDR‑platform
- Audio‑bron (bijv. WAV‑file of live input)

## Installatie & Gebruik

### 1. Kies een projectmap
Ga naar één van de uitgepakte mappen:
- NICAM_RX_Final_Fixed
- NICAM_TX_Final_Fixed
- Final-BPSK-TX-RX

Of pak het bijbehorende .zip‑bestand uit.

### 2. Open de GNU Radio flowgraph
Open het .grc‑bestand in GNU Radio Companion.

### 3. Configureer de SDR‑instellingen
Voor PlutoSDR:
- Frequentie instellen
- Sample‑rate instellen
- Gain instellen
- Buffer‑size instellen

Voor ZYNQ:
- FPGA‑bitstream laden
- IIO‑driver configureren

### 4. Start de flowgraph
RX → je ziet spectrum, constellatie en audio‑output.  
TX → je zendt een NICAM‑signaal uit via Pluto/ZYNQ.

## NICAM 728 – Korte Uitleg

NICAM (Near Instantaneous Companded Audio Multiplex) is een digitale audiostandaard gebruikt in o.a. PAL‑televisie.  
Dit project implementeert:
- NICAM framing
- Companding
- FEC
- BPSK modulatie
- Synchronisatie & timing recovery

## Debug & Analyse

Alle flowgraphs bevatten extra blokken voor:
- Spectrum‑analyse
- Constellatie‑plots
- Timing recovery
- Bit‑error‑analyse
- Logging van symbolen

## Bestanden in deze repository

- NICAM_RX_Final_Fixed/
- NICAM_TX_Final_Fixed/
- Final-BPSK-TX-RX/
- .zip‑archieven van alle projecten
- README.md (dit bestand)

## Auteur

Willem65  
Embedded systems, SDR, NICAM‑experimenten, ZYNQ‑ontwikkeling.

## Licentie

Dit project is vrij te gebruiken voor educatieve en experimentele doeleinden.
