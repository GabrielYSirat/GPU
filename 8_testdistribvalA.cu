#ifdef DISTRIBVAL
for (int apix = 0; apix < THreadsRatio; apix++)
if ((ithreads + THREADSVAL * apix) == center_microimage)
*(distribvalidGPU + iPSF + jPSF * PSFZoom + itc*PSFZOOMSQUARE) = *(shared_distrib + distribpos[apix]);
#endif
