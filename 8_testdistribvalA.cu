#ifdef DISTRIBVAL
for (int apix = 0; apix < THreadsRatio; apix++)
if ((ithreads + THREADSVAL * apix) == center_microimage){
float tempdG = *(shared_distrib + distribpos[apix]);
*(distribvalidGPU + iPSF + jPSF * PSFZoom + itb*PSFZOOMSQUARE) = tempdG;
}
#endif
