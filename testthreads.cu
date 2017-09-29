#ifdef TESTTHREADS
	if (!iprint)
		printf("\n\u2461*******************************DEVICE:  THREADS *********************\n");
	for (int apix = 0; apix < THreadsRatio; apix++) {
		int tmpi = (ithreads + apix * THREADSVAL);
		if(!itb)
			if ((ithreads == 0)||(ithreads == (THREADSVAL-1)) ||(tmpi == PixZoomSquare-1) ||(tmpi == PixZoomSquare))
				printf("DEVICE: \u2461 THREAD : apix %d  ipixel %d, jpixel %d  valid %d distribpos0 %d\n",
						 apix,  ipixel[apix], jpixel[apix], valid_pixel[apix], distribpos0[apix]);
	if(tmpi == (PixZoomSquare-1) || tmpi == PixZoomSquare)
				printf("DEVICE: \u2461 THREAD : apix %d ipixel %d, jpixel %d  valid %d distribpos0 %d\n",
						 apix, ipixel[apix], jpixel[apix], valid_pixel[apix], distribpos0[apix]);
				}
	for (int apix = 0; apix < THreadsRatio; apix++)
	if(!ipixel[apix] && !jpixel[apix]){
				printf("DEVICE CENTER: \u2461 THREAD : apix %d tmpi %d ipixel %d, jpixel %d  valid %d distribpos0 %d center %d\n",
						apix, tmpi[apix], ipixel[apix], jpixel[apix], valid_pixel[apix], distribpos0[apix], center_distrib);
}
	if (!iprint)
		printf("\u2461 **********************************DEVICE:  THREADS  ********************\n\n");
	__syncthreads();
#endif
