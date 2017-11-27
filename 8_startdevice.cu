#ifdef STARTDEVICE
	if(!ithreads && VERBOSELOOP) printf("TEST: block x %d y %d z %d distrib number %d itc %d itb %d\n",
			blockIdx.x, blockIdx.y, blockIdx.z, distrib_number, itc, itb);
		if (!iprint)  	// the condition is required to have it printed once

		if (!iprint) { 	// the condition is required to have it printed once
		printf("\n\u2460********************************** START *****************************\n");
		printf("DEVICE: \u2460****************PARAMETERS OF MEASUREMENT *******************\n");
		printf("DEVICE: \u2460 PARAMETERS  NThreads %d Npixel %d pZOOM %d, pPSF %d\n", NThreads, Npixel, pZOOM, pPSF);
		printf("DEVICE: \u2460 PARAMETERS dimBlock  x: %d y: %d z: %d   ...   ", blockDim.x, blockDim.y, blockDim.z);
		printf("dimGrid  x: %d y: %d z: %d\n", gridDim.x, gridDim.y, gridDim.z);
		printf("DEVICE: \u2460 PARAMETERS pPSF %d XDistrib %d YDistrib %d ADistrib %d\n", pPSF, XDistrib, YDistrib, ADistrib);
		printf("DEVICE: \u2460 PARAMETERS XSCRATCH %d YSCRATCH %d XTILE %d YTILE %d\n", XSCRATCH, YSCRATCH, XTile, YTile);
		printf("DEVICE: \u2460 PARAMETERS Number of pixels calculated in parallel %d Number of threads used"
				" %d loop on threads %d\n", NThreads, THREADSVAL, THreadsRatio);
		printf("DEVICE: \u2460  TILES: XSCRATCH %d, YSCRATCH %d  iprint %d", XSCRATCH, YSCRATCH,iprint);
		printf("XTILE %d, YTILE %d\n", XTile, YTile);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Aggregates in x: %d in y:%d\n", DD.NbAggregx,
				DD.NbAggregy);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Tiles per aggregates in x: %d in y:%d\n",
				DD.tileperaggregatex, DD.tileperaggregatey);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Number of Tiles in x: %d in y:%d\n", DD.NbTilex, DD.NbTiley);
		printf("DEVICE: \u2460  TILES & AGGREGATES: Max number of laser position in Tile: %d min value:%d Number of blocks %d\n",
				DD.maxLaserintile, DD.minLaserintile, DD.blocks);
		printf("\u2460*******************************PARAMETERS OF MEASUREMENT ***************\n");
	}
	__syncthreads();  // to be replaced for group synchronization of CUDA 9.0

	if (!iprint) timer = clock64();
	time_start = timer; time_init = timer;
	if (!iprint)
		printf( "DEVICE: \u23f1**DEVICE:  step %d   TIMING (msec) ** processing  %g this step  %g  total %g \n\n",
			DD.step, (float) (timer - time_start) / DD.clockRate,
			(float) (  time_start - time_init) / DD.clockRate,
			(float) (timer - time_init) / DD.clockRate);

	#endif
