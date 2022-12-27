# Dual Clock FIFO

A simple dual-clock (async) FIFO.

## Notes
* All flags (empty, almost_empty, full, almost_full) are present in the read and write clock domains.
* Resets are synchronous with respect to their input reset signal (separate reset and clock domains).
* Internal counters are double-flopped and gray encoded to ensure maximum data reliability.
* Read data out should probably be registered in the read domain (preferably double-flopped, then almost-empty thresh can be set to 2.)

## Usage
If there are any issues feel free to create an issue or message me via Github.

I won't offer support for integrating into your design, however. It's provided AS-IS.
