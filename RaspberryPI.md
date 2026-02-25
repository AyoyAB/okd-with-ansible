# Installing Raspberry PI 4 as worker

## Enable booting from USB drive

1. Download RPI Imager from [RPi Software](https://www.raspberrypi.com/software/)
2. Insert a spare micro SD card.
3. Run the RPI Imager
4. Choose "Misc utility images"
5. Choose "Bootloader" and then "USB Boot"
6. Write to the SD card
7. Boot the RPI on the SD Card. The green activity light will blink
   in a fast steady pattern once the update has been completed and
   the screen will go green. Wait some more seconds to make sure
   it's really finished.
8. Power off.

## Prepare installation disk

1. Insert a SD card in a virtual Fedora Linux
2. Download CoreOS

   ```shell
   openshift-install coreos print-stream-json | jq -r '.architectures.aarch64.artifacts.metal.formats."raw.xz".disk.location'
   ```

3. Decompress with

   ```shell
   xz -d fedora-coreos-*-metal.aarch64.raw.xz
   ```

4. Write as second partition

