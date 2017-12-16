#ifdef DISTRIBVAL
						for (int apix = 0; apix < THreadsRatio; apix++)
						if ((ithreads + THREADSVAL * apix) == center_microimage)
							*(distribvalidGPU + jPSF * PSFZoom + itb *PSFZOOMSQUARE) = *(shared_distrib + distribpos[apix]);
#endif
